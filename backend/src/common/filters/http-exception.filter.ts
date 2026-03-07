import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

/**
 * Normalised error response body.
 *
 * Every error response produced by this application shares this shape,
 * enabling the Flutter `AuthRepositoryImpl` to apply deterministic
 * mapping from HTTP status codes to typed `Failure` objects.
 *
 * Field semantics:
 * - `statusCode`  — mirrors the HTTP status code for convenience.
 * - `error`       — HTTP reason phrase (e.g. "Conflict", "Unauthorized").
 * - `message`     — human-readable description; safe to display in logs.
 * - `errors`      — field-keyed validation errors; populated only for
 *                   validation failures (HTTP 422). Maps directly to
 *                   `ValidationFailure.errors` on the Flutter client.
 * - `timestamp`   — ISO 8601 UTC; enables server-side log correlation.
 * - `path`        — request URI; useful for client-side error reporting.
 */
export interface ErrorResponseBody {
  statusCode: number;
  error: string;
  message: string;
  errors: Record<string, string> | null;
  timestamp: string;
  path: string;
}

/**
 * Shape of the body produced by NestJS `ValidationPipe` on failure.
 * `message` is an array of class-validator constraint strings when
 * `ValidationPipe` is configured with `exceptionFactory` to produce
 * structured field errors.
 */
interface ValidationExceptionBody {
  message: string | string[] | Record<string, string>;
  error?: string;
  statusCode?: number;
}

/**
 * Global exception filter for all {@link HttpException} subclasses.
 *
 * Responsibilities:
 * 1. Normalise every error response to the {@link ErrorResponseBody} shape.
 * 2. Convert `ValidationPipe` field errors (HTTP 422) into the
 *    `errors: Record<string, string>` map expected by the Flutter client.
 * 3. Log at `warn` level for client errors (4xx) and `error` level for
 *    server errors (5xx), without logging credential values (OWASP A09).
 * 4. Fallback to HTTP 500 for any unhandled non-HttpException thrown
 *    outside a try/catch block — prevents raw stack traces from leaking
 *    to the client (OWASP A09).
 *
 * Registered globally in {@link main.ts} via `app.useGlobalFilters()`.
 */
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const { statusCode, errorPhrase, message, errors } =
      this.extractDetails(exception);

    const body: ErrorResponseBody = {
      statusCode,
      error: errorPhrase,
      message,
      errors,
      timestamp: new Date().toISOString(),
      path: request.url,
    };

    // Log level: warn for 4xx (client error), error for 5xx (server error).
    if (statusCode >= 500) {
      this.logger.error(
        `[${request.method}] ${request.url} → ${statusCode} ${errorPhrase}: ${message}`,
        exception instanceof Error ? exception.stack : undefined,
      );
    } else {
      this.logger.warn(
        `[${request.method}] ${request.url} → ${statusCode} ${errorPhrase}: ${message}`,
      );
    }

    response.status(statusCode).json(body);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private extractDetails(exception: unknown): {
    statusCode: number;
    errorPhrase: string;
    message: string;
    errors: Record<string, string> | null;
  } {
    if (!(exception instanceof HttpException)) {
      // Unhandled non-HTTP exception — do not expose internals.
      return {
        statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
        errorPhrase: 'Internal Server Error',
        message: 'An unexpected error occurred.',
        errors: null,
      };
    }

    const statusCode = exception.getStatus();
    const errorPhrase = this.phraseFor(statusCode);
    const rawBody = exception.getResponse() as ValidationExceptionBody | string;

    // ValidationPipe produces a structured body when exceptionFactory is
    // configured to return UnprocessableEntityException (HTTP 422).
    if (statusCode === HttpStatus.UNPROCESSABLE_ENTITY) {
      const { message, errors } = this.parseValidationBody(rawBody);
      return { statusCode, errorPhrase, message, errors };
    }

    // All other HttpExceptions — extract a plain string message.
    const message =
      typeof rawBody === 'string'
        ? rawBody
        : typeof rawBody.message === 'string'
          ? rawBody.message
          : 'An error occurred.';

    return { statusCode, errorPhrase, message, errors: null };
  }

  /**
   * Parses the ValidationPipe exception body into a normalised message
   * and a field-keyed `errors` map.
   *
   * When `exceptionFactory` returns structured errors in the form
   * `{ errors: { fieldName: 'constraint message' } }`, they are forwarded
   * directly. Otherwise the raw `message` array is flattened.
   */
  private parseValidationBody(
    rawBody: ValidationExceptionBody | string,
  ): { message: string; errors: Record<string, string> | null } {
    if (typeof rawBody === 'string') {
      return { message: rawBody, errors: null };
    }

    // Structured field errors injected by the custom exceptionFactory.
    if (
      typeof rawBody.message === 'object' &&
      !Array.isArray(rawBody.message)
    ) {
      return {
        message: 'Validation failed.',
        errors: rawBody.message as Record<string, string>,
      };
    }

    // Array of constraint strings from the default ValidationPipe format.
    if (Array.isArray(rawBody.message)) {
      return {
        message: 'Validation failed.',
        errors: { form: rawBody.message.join('; ') },
      };
    }

    return {
      message:
        typeof rawBody.message === 'string'
          ? rawBody.message
          : 'Validation failed.',
      errors: null,
    };
  }

  /** Maps an HTTP status code to its standard reason phrase. */
  private phraseFor(statusCode: number): string {
    const phrases: Record<number, string> = {
      400: 'Bad Request',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      409: 'Conflict',
      422: 'Unprocessable Entity',
      429: 'Too Many Requests',
      500: 'Internal Server Error',
      502: 'Bad Gateway',
      503: 'Service Unavailable',
    };
    return phrases[statusCode] ?? 'Error';
  }
}