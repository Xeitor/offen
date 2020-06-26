// Copyright 2020 - Offen Authors <hioffen@posteo.de>
// SPDX-License-Identifier: Apache-2.0

package ratelimiter

import (
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"fmt"
	"time"
)

var (
	errInvalidCache        = errors.New("ratelimiter: invalid value in cache")
	errWouldExceedDeadline = errors.New("ratelimiter: applicable rate limit would exceed give deadline")
)

// GetSetter needs to be implemented by any cache that is
// to be used for storing limits
type GetSetter interface {
	Get(key string) (interface{}, bool)
	Set(key string, value interface{}, expiry time.Duration)
}

// Throttler needs to be implemented by any rate limiter
type Throttler interface {
	Throttle(identifier string) <-chan Result
	Throttlef(format string, args ...interface{}) <-chan Result
}

// Limiter can be used to rate limit operations
// based on an identifier and a threshold value
type Limiter struct {
	threshold time.Duration
	deadline  time.Duration
	cache     GetSetter
	salt      []byte
}

// Result describes the outcome of a `Throttle` call
type Result struct {
	Error error
	Delay time.Duration
}

// Throttle returns a channel that blocks until the configured
// rate limit has been satisfied. The channel will send a `Result` exactly
// once before closing, containing information on the
// applied rate limiting or possible errors that occured
func (l *Limiter) Throttle(rawIdentifier string) <-chan Result {
	joined := append([]byte(rawIdentifier), l.salt...)
	identifier := fmt.Sprintf("%x", sha256.Sum256(joined))

	out := make(chan Result)
	go func() {
		if value, found := l.cache.Get(identifier); found {
			if timeout, ok := value.(time.Time); ok {
				remaining := time.Until(timeout)
				if remaining > l.deadline {
					out <- Result{Error: errWouldExceedDeadline}
					return
				}
				l.cache.Set(
					identifier,
					timeout.Add(l.threshold),
					remaining,
				)
				time.Sleep(remaining)
				out <- Result{Delay: remaining}
			} else {
				out <- Result{Error: errInvalidCache}
			}
		} else {
			l.cache.Set(identifier, time.Now().Add(l.threshold), l.threshold)
			out <- Result{}
		}
		close(out)
	}()
	return out
}

// Throttlef calls Throttle while applying the given args to the format
func (l *Limiter) Throttlef(format string, args ...interface{}) <-chan Result {
	return l.Throttle(fmt.Sprintf(format, args...))
}

// New creates a new Throttler using Limiter. `threshold` defines the
// enforced minimum distance between two calls of the
// instance's `Throttle` method using the same identifier
func New(threshold, timeout time.Duration, cache GetSetter) *Limiter {
	salt, err := randomBytes(16)
	if err != nil {
		panic("cannot initialize rate limiter")
	}
	return &Limiter{
		cache:     cache,
		threshold: threshold,
		deadline:  timeout,
		salt:      salt,
	}
}

func randomBytes(size int) ([]byte, error) {
	b := make([]byte, size)
	_, err := rand.Read(b)
	if err != nil {
		return nil, fmt.Errorf("ratelimiter: error reading random bytes: %w", err)
	}
	return b, nil
}
