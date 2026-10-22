package com.devtrack.exception;

import org.springframework.http.HttpStatus;

/**
 * Base class for all business errors. GlobalExceptionHandler turns these into
 * a JSON body of the form {"status": ..., "error": ..., "message": ...}.
 */
public class ApiException extends RuntimeException {

    private final HttpStatus status;

    public ApiException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() { return status; }
}
