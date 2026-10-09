import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jamejam/core/secret_store.dart';
import 'package:jamejam/features/settings/memory_settings_store.dart';
import 'package:jamejam/features/settings/setting_keys.dart';
import 'package:jamejam/features/settings/settings_controller.dart';
import 'package:jamejam/features/soroush/ai_funnel.dart';
import 'package:jamejam/features/soroush/soroush_client.dart';
import 'package:jamejam/features/soroush/soroush_options.dart';

String _completion(String content) => jsonEncode({
  'choices': [
    {
      'message': {'content': content},
    },
  ],
});

void main() {
  late SettingsController settings;
  late MemorySecretStore secrets;
  late List<http.Request> requests;

  /// Builds the funnel the tests drive.
  ///
  /// `withKey` seeds the secret store: the funnel refuses a non-loopback endpoint without a
  /// key (the .NET's `CompleteAiRequestAsync` gate), so a test that wants to reach a *later*
  /// check — the prompt rails, for instance — has to get past the gate first.
  Future<AiFunnel> buildFunnel({bool withKey = false}) async {
    requests = [];
    if (withKey) {
      await secrets.write(SecretKeys.aiApiKey, 'sk-test');
    }
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(_completion('Done.'), 200);
    });
    return AiFunnel(
      settings: settings,
      secrets: EnvironmentFirstSecretStore(secrets, environment: const {}),
      httpClient: client,
    );
  }

  setUp(() async {
    settings = SettingsController(MemorySettingsStore());
    await settings.load();
    secrets = MemorySecretStore();
  });

  test(
    'resolves endpoint and model from the provider default when nothing is set',
    () async {
      final funnel = await buildFunnel();
      final options = await funnel.resolve();

      expect(options.provider, 'openai');
      expect(options.endpoint, SoroushDefaults.openAiCompatibleEndpoint);
      expect(options.model, isNull);
    },
  );

  test('an anthropic selection never keeps the OpenAI endpoint', () async {
    await settings.set(SettingKeys.soroushProvider, 'anthropic');
    final funnel = await buildFunnel();

    final options = await funnel.resolve();
    expect(options.provider, 'anthropic');
    expect(options.endpoint, SoroushDefaults.anthropicEndpoint);
  });

  test('resolution order is flag → settings → provider default', () async {
    await settings.set(SettingKeys.soroushModel, 'from-settings');
    final funnel = await buildFunnel();

    expect((await funnel.resolve()).model, 'from-settings');
    expect((await funnel.resolve(model: 'from-flag')).model, 'from-flag');
  });

  test(
    'reads the API key from the secret store, never from settings',
    () async {
      final funnel = await buildFunnel();
      expect(await funnel.readApiKey(), isNull);

      await secrets.write(SecretKeys.aiApiKey, 'sk-from-keychain');
      expect(await funnel.readApiKey(), 'sk-from-keychain');
      expect(await funnel.maskedApiKey(), '****hain');
      expect(await funnel.hasUsableKey(), isTrue);

      await funnel.clearApiKey();
      expect(await funnel.readApiKey(), isNull);
      expect(await funnel.hasUsableKey(), isFalse);
    },
  );

  test('a loopback endpoint needs no key at all', () async {
    await settings.set(
      SettingKeys.soroushEndpoint,
      'http://localhost:11434/v1/chat/completions',
    );
    final funnel = await buildFunnel();

    expect(await funnel.hasUsableKey(), isTrue);
    final result = await funnel.completeText('hi');
    expect(result, 'Done.');
    expect(requests.single.url.host, 'localhost');
    expect(requests.single.headers.containsKey('authorization'), isFalse);
  });

  test('end-to-end completion sends the resolved model and key', () async {
    await secrets.write(SecretKeys.aiApiKey, 'sk-test');
    await settings.set(SettingKeys.soroushModel, 'gpt-4o-mini');
    final funnel = await buildFunnel();

    final result = await funnel.complete(const AiRequest(prompt: 'Say hi'));
    expect(result.content, 'Done.');
    expect(result.provider, 'openai');
    expect(result.attempts, 1);

    final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(sent['model'], 'gpt-4o-mini');
    expect(requests.single.headers['authorization'], 'Bearer sk-test');
  });

  test('invalid prompt fails before any network call', () async {
    final funnel = await buildFunnel(withKey: true);
    await expectLater(
      funnel.complete(const AiRequest(prompt: '   ')),
      throwsA(isA<ArgumentError>()),
    );
    expect(requests, isEmpty);
  });
}
