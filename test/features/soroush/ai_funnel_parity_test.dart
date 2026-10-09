// Parity port of tests/JameJam.Tests/AppSoroushTests.cs (8 cases) and the settings-provider
// cases from AppSettingsTests.cs.
//
// AppSoroushTests exercises the CLI command `JameJam soroush …`; the equivalents here run
// against AiFunnel, which is the same resolution + gate logic without the argument parser.
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

  /// The .NET's own suite always carried a key (`ApiKey = "test-key-1234"`); `withKey` does
  /// the same here, so a test can get past the gate and reach the check it is about.
  Future<AiFunnel> funnel({
    http.Response? response,
    int status = 200,
    bool withKey = false,
  }) async {
    requests = [];
    if (withKey) {
      await secrets.write(SecretKeys.aiApiKey, 'sk-test');
    }
    return AiFunnel(
      settings: settings,
      secrets: EnvironmentFirstSecretStore(secrets, environment: const {}),
      httpClient: MockClient((request) async {
        requests.add(request);
        return response ?? http.Response(_completion('Done.'), status);
      }),
    );
  }

  setUp(() async {
    settings = SettingsController(MemorySettingsStore());
    await settings.load();
    secrets = MemorySecretStore();
  });

  group('AppSoroushTests parity', () {
    // MissingKey_OnNonLoopbackEndpoint_Fails
    test('a missing key on a non-loopback endpoint fails the gate', () async {
      final ai = await funnel();
      expect(await ai.hasUsableKey(), isFalse);
      expect(await ai.readApiKey(), isNull);
    });

    // LoopbackEndpoint_AllowsMissingKey
    test('a loopback endpoint allows a missing key', () async {
      await settings.set(
        SettingKeys.soroushEndpoint,
        'http://localhost:11434/v1/chat/completions',
      );
      final ai = await funnel();

      expect(await ai.hasUsableKey(), isTrue);
      expect(await ai.completeText('hi'), 'Done.');
      expect(requests.single.headers.containsKey('authorization'), isFalse);
    });

    // Flags_FlowIntoOptions_AndPromptIsJoined
    test('overrides flow into the resolved options', () async {
      await settings.set(SettingKeys.soroushModel, 'from-settings');
      await settings.set(
        SettingKeys.soroushEndpoint,
        'https://settings.example/v1',
      );
      final ai = await funnel();

      final options = await ai.resolve(
        provider: 'anthropic',
        model: 'from-call',
        endpoint: 'https://call.example/v1',
      );

      expect(options.provider, 'anthropic');
      expect(options.model, 'from-call');
      expect(options.endpoint, 'https://call.example/v1');
    });

    // Settings_ProvideDefaults
    test('settings provide the defaults when nothing overrides them', () async {
      await settings.set(SettingKeys.soroushProvider, 'anthropic');
      await settings.set(SettingKeys.soroushModel, 'claude-3-5-haiku-latest');
      final ai = await funnel();

      final options = await ai.resolve();
      expect(options.provider, 'anthropic');
      expect(options.model, 'claude-3-5-haiku-latest');
      // The Anthropic endpoint, not the OpenAI one — the divergence documented in the README.
      expect(options.endpoint, SoroushDefaults.anthropicEndpoint);
    });

    // EmptyPrompt_Fails
    test('an empty prompt fails', () async {
      final ai = await funnel(withKey: true);
      await expectLater(
        ai.complete(const AiRequest(prompt: '   ')),
        throwsA(isA<ArgumentError>()),
      );
      expect(requests, isEmpty);
    });

    // TooLongPrompt_FailsWithoutHttpCall
    test('a too-long prompt fails without an HTTP call', () async {
      final ai = await funnel();
      await expectLater(
        ai.complete(
          AiRequest(prompt: 'p' * (SoroushLimits.defaultMaxPromptLength + 1)),
        ),
        throwsA(isA<SoroushException>()),
      );
      expect(requests, isEmpty);
    });

    // UnknownProvider_Fails
    test('an unknown provider fails', () async {
      final ai = await funnel();
      await expectLater(
        ai.resolve(provider: 'not-a-provider'),
        throwsA(isA<SoroushException>()),
      );
      expect(requests, isEmpty);
    });

    // ClientFailure_SurfacesMessage
    test('a client failure surfaces its message', () async {
      await secrets.write(SecretKeys.aiApiKey, 'sk-test');
      final ai = await funnel(
        response: http.Response('server exploded', 500),
        status: 500,
      );

      await expectLater(
        ai.complete(const AiRequest(prompt: 'hi')),
        throwsA(
          isA<SoroushException>().having(
            (e) => e.message,
            'message',
            contains('server exploded'),
          ),
        ),
      );
    });
  });

  group('AppSettingsTests parity — provider settings', () {
    // Greet_UsesDefaultNameSetting_WhenNoArgs is covered in the widget tests; these are the
    // settings-resolution halves.
    test('the key is read from the secret store, not from settings', () async {
      final ai = await funnel();
      expect(await ai.readApiKey(), isNull);

      await secrets.write(SecretKeys.aiApiKey, 'sk-in-keychain');
      expect(await ai.readApiKey(), 'sk-in-keychain');
      expect(await ai.maskedApiKey(), '****hain');
    });

    // The environment must win over the keychain, exactly like the CLI.
    test(
      'an environment variable takes precedence over the stored key',
      () async {
        await secrets.write(SecretKeys.aiApiKey, 'sk-from-keychain');
        final ai = AiFunnel(
          settings: settings,
          secrets: EnvironmentFirstSecretStore(
            secrets,
            environment: const {SecretKeys.aiApiKeyEnv: 'sk-from-env'},
          ),
          httpClient: MockClient(
            (_) async => http.Response(_completion('ok'), 200),
          ),
        );

        expect(await ai.readApiKey(), 'sk-from-env');
      },
    );

    // The settings database still refuses to hold a key at all.
    test('the settings store refuses to hold an API key', () async {
      final refusal = await settings.set('soroush.apiKey', 'sk-nope');
      expect(refusal, isNotNull);
      expect(refusal, contains('secret'));
    });
  });
}
