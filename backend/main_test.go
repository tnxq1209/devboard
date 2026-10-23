package main

import "testing"

// TestEnvReturnsFallbackWhenUnset checks the fallback behavior.
func TestEnvReturnsFallbackWhenUnset(t *testing.T) {
	t.Setenv("DEVBOARD_TEST_KEY", "")

	if got := env("DEVBOARD_TEST_KEY", "fallback"); got != "fallback" {
		t.Errorf("env() = %q, want %q", got, "fallback")
	}
}

// TestEnvReturnsValueWhenSet checks the configured value.
func TestEnvReturnsValueWhenSet(t *testing.T) {
	t.Setenv("DEVBOARD_TEST_KEY", "real")

	if got := env("DEVBOARD_TEST_KEY", "fallback"); got != "real" {
		t.Errorf("env() = %q, want %q", got, "real")
	}
}
