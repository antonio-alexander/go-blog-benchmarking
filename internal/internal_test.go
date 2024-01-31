package internal_test

import (
	"testing"

	"github.com/antonio-alexander/go-blog-benchmarking/internal"

	"github.com/stretchr/testify/assert"
)

func TestFibonacci(t *testing.T) {
	cases := map[string]struct {
		inN  int
		outN int
	}{
		"": {
			inN:  1,
			outN: 1,
		},
	}
	for cDesc, c := range cases {
		n := internal.Fibonacci(c.inN)
		assert.Equalf(t, c.outN, n, "Fibonacci: %s", cDesc)
	}
	for cDesc, c := range cases {
		n := internal.FibonacciRecursive(c.inN)
		assert.Equal(t, c.outN, n, "FibonacciRecursive: %s", cDesc)
	}
}

func BenchmarkFibonacci(b *testing.B) {
	const n int = 10

	for i := 0; i < b.N; i++ {
		internal.Fibonacci(n)
	}
}
