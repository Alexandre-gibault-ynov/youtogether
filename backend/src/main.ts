import {NestFactory, Reflector} from '@nestjs/core';
import {ClassSerializerInterceptor, HttpStatus, UnprocessableEntityException, ValidationPipe,} from '@nestjs/common';
import {ConfigType} from '@nestjs/config';
import {DocumentBuilder, SwaggerModule} from '@nestjs/swagger';

import {AppModule} from './app.module';
import {HttpExceptionFilter} from './common/filters/http-exception.filter';
import {appConfig} from './config';

/**
 * Application bootstrap.
 *
 * Global configuration:
 *
 * - {@link HttpExceptionFilter} — normalises every error response to the
 *   `ErrorResponseBody` envelope consumed by the Flutter client.
 *
 * - {@link ValidationPipe} — validates incoming request bodies against DTOs.
 *   `exceptionFactory` converts class-validator errors into a structured
 *   `UnprocessableEntityException` (HTTP 422) with a field-keyed `errors` map.
 *
 * - {@link ClassSerializerInterceptor} — applies `class-transformer`
 *   decorators when serialising responses.
 *
 * - Swagger UI — served at `/api/docs` in non-production environments.
 *   The raw OpenAPI JSON spec is available at `/api/docs-json`.
 *
 * - Port and CORS origin are read from the typed `app` configuration namespace.
 */
async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);

  const cfg = app.get<ConfigType<typeof appConfig>>(appConfig.KEY);

  app.setGlobalPrefix('api');

  // Normalise all error responses to a consistent JSON envelope.
  app.useGlobalFilters(new HttpExceptionFilter());

  // Input validation — structured 422 for field errors.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
      errorHttpStatusCode: HttpStatus.UNPROCESSABLE_ENTITY,
      exceptionFactory: (validationErrors) => {
        const errors = validationErrors.reduce<Record<string, string>>(
          (acc, err) => {
            const constraints = err.constraints ?? {};
            acc[err.property] = Object.values(constraints)[0] ?? 'Invalid value.';
            return acc;
          },
          {},
        );
        return new UnprocessableEntityException({ message: errors });
      },
    }),
  );

  // Response serialisation via class-transformer decorators.
  const reflector = app.get(Reflector);
  app.useGlobalInterceptors(new ClassSerializerInterceptor(reflector));

  // ── Swagger ──────────────────────────────────────────────────────────────────
  // Swagger UI is disabled in production to avoid leaking API internals.
  if (cfg.nodeEnv !== 'production') {
    const swaggerConfig = new DocumentBuilder()
      .setTitle('YouTogether API')
      .setDescription(
        'REST API for the YouTogether watch-party application.\n\n' +
        '**Authentication flow:**\n' +
        '1. `POST /api/auth/register` or `POST /api/auth/login` to obtain `access_token` and `refresh_token`.\n' +
        '2. Pass `Authorization: Bearer <access_token>` on protected endpoints.\n' +
        '3. When the access token expires, call `POST /api/auth/refresh` with `Authorization: Bearer <refresh_token>` to rotate the token pair.\n' +
        '4. Call `POST /api/auth/logout` to invalidate the session server-side.\n\n' +
        '**Error envelope:** every error response shares the `ErrorResponseBody` shape ' +
        '(`statusCode`, `error`, `message`, `errors`, `timestamp`, `path`). ' +
        'HTTP 422 responses populate `errors` with a field-keyed validation map.',
      )
      .setVersion('1.1.0')
      .setContact('YouTogether', '', '')
      .addBearerAuth(
        {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Short-lived access token (default TTL: 15 minutes). Obtained from /auth/register or /auth/login.',
          name: 'Authorization',
          in: 'header',
        },
        'access-token',
      )
      .addBearerAuth(
        {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Long-lived refresh token (default TTL: 7 days). Obtained from /auth/register or /auth/login. Used exclusively with POST /auth/refresh.',
          name: 'Authorization',
          in: 'header',
        },
        'refresh-token',
      )
      .addServer(`http://localhost:${cfg.port}`, 'Local development')
      .addServer('https://api.youtogether.example.com', 'Production')
      .build();

    const document = SwaggerModule.createDocument(app, swaggerConfig);

    // Swagger UI at /api/docs
    SwaggerModule.setup('api/docs', app, document, {
      swaggerOptions: {
        // Persist the Bearer token between page reloads in the browser.
        persistAuthorization: true,
        // Expand all operations by default for easier navigation.
        docExpansion: 'list',
        // Display request duration in responses.
        displayRequestDuration: true,
        // Sort endpoints alphabetically within each tag.
        operationsSorter: 'alpha',
      },
      customSiteTitle: 'YouTogether API Docs',
    });
  }

  app.enableCors({
    origin: cfg.corsOrigin,
    methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  await app.listen(cfg.port);
}

void bootstrap();