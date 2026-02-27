import {
  ArgumentsHost,
  ConflictException,
  ForbiddenException,
  HttpStatus,
  NotFoundException,
  UnauthorizedException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';

import {
  HttpExceptionFilter,
  ErrorResponseBody,
} from '../../../src/common/filters/http-exception.filter';

// ---------------------------------------------------------------------------
// ArgumentsHost mock
// ---------------------------------------------------------------------------

function buildHost(url = '/api/auth/register', method = 'POST'): ArgumentsHost {
  const mockJson = jest.fn();
  const mockStatus = jest.fn().mockReturnValue({ json: mockJson });
  const mockResponse = { status: mockStatus };
  const mockRequest = { url, method };

  return {
    switchToHttp: () => ({
      getResponse: () => mockResponse,
      getRequest: () => mockRequest,
    }),
  } as unknown as ArgumentsHost;
}

/** Extracts the body passed to `response.status(n).json(body)`. */
function captureBody(host: ArgumentsHost): ErrorResponseBody {
  const ctx = host.switchToHttp();
  const response = ctx.getResponse<{ status: jest.Mock }>();
  const statusResult = response.status.mock.results[0]?.value as {
    json: jest.Mock;
  };
  return statusResult.json.mock.calls[0]?.[0] as ErrorResponseBody;
}

/** Extracts the HTTP status code passed to `response.status(n)`. */
function captureStatus(host: ArgumentsHost): number {
  const ctx = host.switchToHttp();
  const response = ctx.getResponse<{ status: jest.Mock }>();
  return response.status.mock.calls[0]?.[0] as number;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('HttpExceptionFilter', () => {
  let filter: HttpExceptionFilter;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [HttpExceptionFilter],
    }).compile();
    filter = module.get<HttpExceptionFilter>(HttpExceptionFilter);
  });

  // ── Envelope shape ─────────────────────────────────────────────────────────

  describe('response envelope', () => {
    it('always includes statusCode, error, message, errors, timestamp and path', () => {
      const host = buildHost('/api/auth/me', 'GET');
      filter.catch(new UnauthorizedException('Access token is missing or invalid.'), host);

      const body = captureBody(host);

      expect(body).toMatchObject({
        statusCode: HttpStatus.UNAUTHORIZED,
        error: 'Unauthorized',
        message: expect.any(String),
        timestamp: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/),
        path: '/api/auth/me',
      });
      expect('errors' in body).toBe(true);
    });
  });

  // ── 401 Unauthorized ───────────────────────────────────────────────────────

  describe('UnauthorizedException (401)', () => {
    it('produces statusCode 401 with the exception message', () => {
      const host = buildHost();
      filter.catch(
        new UnauthorizedException('Invalid email or password.'),
        host,
      );

      expect(captureStatus(host)).toBe(401);
      expect(captureBody(host).message).toBe('Invalid email or password.');
      expect(captureBody(host).errors).toBeNull();
    });
  });

  // ── 403 Forbidden ──────────────────────────────────────────────────────────

  describe('ForbiddenException (403)', () => {
    it('produces statusCode 403', () => {
      const host = buildHost('/api/auth/refresh', 'POST');
      filter.catch(
        new ForbiddenException('Refresh token is invalid. Please log in again.'),
        host,
      );

      expect(captureStatus(host)).toBe(403);
      expect(captureBody(host).error).toBe('Forbidden');
    });
  });

  // ── 404 Not Found ──────────────────────────────────────────────────────────

  describe('NotFoundException (404)', () => {
    it('produces statusCode 404 with the exception message', () => {
      const host = buildHost('/api/users/nonexistent', 'GET');
      filter.catch(new NotFoundException('User not found.'), host);

      expect(captureStatus(host)).toBe(404);
      expect(captureBody(host).message).toBe('User not found.');
    });
  });

  // ── 409 Conflict ───────────────────────────────────────────────────────────

  describe('ConflictException (409)', () => {
    it('produces statusCode 409 with no errors map', () => {
      const host = buildHost();
      filter.catch(
        new ConflictException(
          'An account with this email address already exists.',
        ),
        host,
      );

      expect(captureStatus(host)).toBe(409);
      expect(captureBody(host).error).toBe('Conflict');
      expect(captureBody(host).errors).toBeNull();
      expect(captureBody(host).message).toBe(
        'An account with this email address already exists.',
      );
    });
  });

  // ── 422 Unprocessable Entity ───────────────────────────────────────────────

  describe('UnprocessableEntityException (422)', () => {
    it('produces statusCode 422 with structured field-keyed errors map', () => {
      const host = buildHost();
      // Simulate the body produced by the ValidationPipe exceptionFactory
      filter.catch(
        new UnprocessableEntityException({
          message: {
            email: 'email must be a valid email address.',
            password: 'password must be at least 8 characters.',
          },
        }),
        host,
      );

      const body = captureBody(host);
      expect(captureStatus(host)).toBe(422);
      expect(body.error).toBe('Unprocessable Entity');
      expect(body.message).toBe('Validation failed.');
      expect(body.errors).toEqual({
        email: 'email must be a valid email address.',
        password: 'password must be at least 8 characters.',
      });
    });

    it('flattens array messages from the default ValidationPipe format', () => {
      const host = buildHost();
      filter.catch(
        new UnprocessableEntityException({
          message: [
            'email must be a valid email address.',
            'password must be at least 8 characters.',
          ],
        }),
        host,
      );

      const body = captureBody(host);
      expect(body.errors).toEqual({
        form: 'email must be a valid email address.; password must be at least 8 characters.',
      });
    });

    it('handles a plain string message in the 422 body', () => {
      const host = buildHost();
      filter.catch(
        new UnprocessableEntityException('Validation failed.'),
        host,
      );

      const body = captureBody(host);
      expect(body.errors).toBeNull();
      expect(body.message).toBe('Validation failed.');
    });
  });

  // ── 500 Internal Server Error ──────────────────────────────────────────────

  describe('non-HttpException (500)', () => {
    it('produces statusCode 500 without leaking internal details', () => {
      const host = buildHost('/api/auth/login', 'POST');
      filter.catch(new Error('TypeORM connection refused'), host);

      const body = captureBody(host);
      expect(captureStatus(host)).toBe(500);
      expect(body.error).toBe('Internal Server Error');
      expect(body.message).toBe('An unexpected error occurred.');
      expect(body.errors).toBeNull();
    });

    it('handles non-Error thrown values (string, null, undefined)', () => {
      const host = buildHost();
      // eslint-disable-next-line @typescript-eslint/only-throw-error
      filter.catch('unexpected string thrown', host);

      expect(captureStatus(host)).toBe(500);
      expect(captureBody(host).message).toBe('An unexpected error occurred.');
    });
  });

  // ── Path reflection ────────────────────────────────────────────────────────

  describe('path field', () => {
    it('reflects the request URL in the response body', () => {
      const host = buildHost('/api/auth/me', 'GET');
      filter.catch(new UnauthorizedException(), host);

      expect(captureBody(host).path).toBe('/api/auth/me');
    });
  });

  // ── Timestamp ─────────────────────────────────────────────────────────────

  describe('timestamp field', () => {
    it('is a valid ISO 8601 UTC string', () => {
      const host = buildHost();
      filter.catch(new UnauthorizedException(), host);

      const { timestamp } = captureBody(host);
      expect(() => new Date(timestamp)).not.toThrow();
      expect(timestamp).toMatch(/Z$/);
    });
  });
});