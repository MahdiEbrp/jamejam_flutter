// Parity port of tests/JameJam.Tests/Soroush/Providers/SoroushProvidersTests.cs
// (9 facts + 1 theory, 16 cases).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamejam/features/soroush/soroush_options.dart';
import 'package:jamejam/features/soroush/soroush_registry.dart';

void main() {
  group('SoroushProvidersTests parity', () {
    // Resolve_KnownNames_ReturnProvider  [7 inline]
    test('known names resolve to their provider', () {
      expect(SoroushProviders.resolve('openai').name, 'openai');
      expect(SoroushProviders.resolve('openai-compatible').name, 'openai');
      expect(SoroushProviders.resolve('anthropic').name, 'anthropic');
      expect(SoroushProviders.resolve('claude').name, 'anthropic');
      expect(SoroushProviders.resolve('azure').name, 'openai');
      expect(SoroushProviders.resolve('groq').name, 'openai');
      expect(SoroushProviders.resolve('ollama').name, 'openai');
    });

    // Resolve_Blank_DefaultsToOpenAiCompatible
    test('a blank name defaults to the OpenAI-compatible provider', () {
      expect(SoroushProviders.resolve(null).name, 'openai');
      expect(SoroushProviders.resolve('').name, 'openai');
      expect(SoroushProviders.resolve('   ').name, 'openai');
    });

    // Resolve_Unknown_Throws
    test('an unknown name throws', () {
      expect(
        () => SoroushProviders.resolve('definitely-not-a-provider'),
        throwsA(isA<SoroushException>()),
      );
    });

    // The .NET dictionary is OrdinalIgnoreCase — the same must hold here.
    test('resolution is case-insensitive', () {
      expect(SoroushProviders.resolve('OPENAI').name, 'openai');
      expect(SoroushProviders.resolve('AnThRoPiC').name, 'anthropic');
      expect(SoroushProviders.resolve('  Claude  ').name, 'anthropic');
    });

    // AnthropicProvider_ApiVersion_IsConfigurable
    test('the Anthropic API version is configurable', () {
      const provider = AnthropicProvider(apiVersion: '2024-01-01');
      final request = provider.buildRequest(
        options: const SoroushOptions(apiKey: 'sk-test'),
        endpoint: SoroushDefaults.anthropicEndpoint,
        prompt: 'hi',
      );
      expect(request.headers['anthropic-version'], '2024-01-01');
    });

    // AnthropicProvider_BlankApiVersion_Throws
    // (The .NET constructor throws; Dart's const constructor cannot, so the same contract
    // is enforced by validate() — which buildRequest always calls first.)
    test('a blank Anthropic API version throws', () {
      // The default is valid.
      expect(const AnthropicProvider().validate, returnsNormally);

      for (final blank in ['', '   ']) {
        final blankProvider = AnthropicProvider(apiVersion: blank);
        expect(
          blankProvider.validate,
          throwsArgumentError,
          reason: 'apiVersion = "$blank"',
        );
        expect(
          () => blankProvider.buildRequest(
            options: const SoroushOptions(apiKey: 'sk-test'),
            endpoint: SoroushDefaults.anthropicEndpoint,
            prompt: 'hi',
          ),
          throwsArgumentError,
        );
      }
    });

    // AnthropicProvider_MalformedBody_ProducesFriendlyError
    test('an Anthropic malformed body produces a friendly error', () {
      expect(
        () => const AnthropicProvider().parseResponse('{"nope":true}'),
        throwsA(
          isA<SoroushException>().having(
            (e) => e.message,
            'message',
            contains('unexpected Anthropic response shape'),
          ),
        ),
      );
    });

    // AnthropicProvider_EmptyContentBlocks_ProducesFriendlyError
    test('empty Anthropic content blocks produce a friendly error', () {
      expect(
        () => const AnthropicProvider().parseResponse('{"content":[]}'),
        throwsA(
          isA<SoroushException>().having(
            (e) => e.message,
            'message',
            contains('no text blocks'),
          ),
        ),
      );
    });

    // AnthropicProvider_EmptyText_ThrowsViaSafetyLayer
    test('empty Anthropic text throws through the safety layer', () {
      expect(
        () => const AnthropicProvider().parseResponse(
          '{"content":[{"type":"text","text":"   "}]}',
        ),
        throwsA(isA<SoroushException>()),
      );
    });

    // OpenAICompatibleProvider_MalformedBody_ProducesFriendlyError
    test('an OpenAI-compatible malformed body produces a friendly error', () {
      expect(
        () => const OpenAICompatibleProvider().parseResponse('not json at all'),
        throwsA(
          isA<SoroushException>().having(
            (e) => e.message,
            'message',
            contains('unexpected OpenAI-compatible response shape'),
          ),
        ),
      );
    });

    // Names_IncludesCanonicalProviders
    test('the registry advertises its canonical providers', () {
      expect(SoroushProviders.canonical, contains('openai'));
      expect(SoroushProviders.canonical, contains('anthropic'));
      expect(
        SoroushProviders.names,
        containsAll(['openai', 'anthropic', 'claude']),
      );
    });

    // Provider defaults — the endpoints/models the settings screen falls back to.
    test('provider defaults are the canonical ones', () {
      expect(
        SoroushProviders.resolve('openai').defaultEndpoint,
        SoroushDefaults.openAiCompatibleEndpoint,
      );
      expect(
        SoroushProviders.resolve('openai').defaultModel,
        SoroushDefaults.openAiCompatibleModel,
      );
      expect(
        SoroushProviders.resolve('anthropic').defaultEndpoint,
        SoroushDefaults.anthropicEndpoint,
      );
      expect(
        SoroushProviders.resolve('anthropic').defaultModel,
        SoroushDefaults.anthropicModel,
      );
    });

    // Every alias must actually speak its provider's wire format.
    test('every alias builds a request its provider understands', () {
      for (final alias in SoroushProviders.names) {
        final provider = SoroushProviders.resolve(alias);
        final request = provider.buildRequest(
          options: const SoroushOptions(apiKey: 'sk-test'),
          endpoint: provider.defaultEndpoint,
          prompt: 'hi',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['messages'], isNotEmpty, reason: alias);
        expect(body['max_tokens'], isNotNull, reason: alias);
        if (provider.name == 'anthropic') {
          expect(request.headers['x-api-key'], 'sk-test', reason: alias);
        } else {
          expect(
            request.headers['authorization'],
            'Bearer sk-test',
            reason: alias,
          );
        }
      }
    });

    // An explicit model override must win over the provider default in both shapes.
    test('an explicit model overrides the provider default', () {
      for (final provider in [
        const OpenAICompatibleProvider(),
        const AnthropicProvider(),
      ]) {
        final request = provider.buildRequest(
          options: const SoroushOptions(
            apiKey: 'sk-test',
            model: 'custom-model',
          ),
          endpoint: provider.defaultEndpoint,
          prompt: 'hi',
        );
        expect(jsonDecode(request.body)['model'], 'custom-model');
      }
    });

    // Anthropic aliases resolve case-insensitively too (covered above) and the canonical
    // list stays exactly two entries, as the settings dropdown expects.
    test('exactly two canonical providers are offered', () {
      expect(SoroushProviders.canonical, hasLength(2));
    });
  });
}
