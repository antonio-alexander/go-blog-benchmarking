## ----------------------------------------------------------------------
## This makefile can be used to execute common functions to interact with
## the source code, these functions ease local development and can also be
## used in CI/CD pipelines.
## ----------------------------------------------------------------------

SHELL=/bin/bash
.SHELLFLAGS = -o pipefail -c

test_timeout=20m

benchmark_count=27
benchmark_time=1s
benchstat_golden_file=./benchmarks/go-blog-benchmarking_benchmark-golden.log
benchstat_version=latest
benchstat_args=

.PHONY: help check-lint lint lint-verbose check-godoc serve-godoc test test-verbose

# REFERENCE: https://stackoverflow.com/questions/16931770/makefile4-missing-separator-stop
help: ## - Show this help.
	@sed -ne '/@sed/!s/## //p' $(MAKEFILE_LIST)

check-lint: ## - validate/install golangci-lint installation
	@which golangci-lint || (go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.44.2)

lint: check-lint ## - lint the source
	@golangci-lint run

lint-verbose: check-lint ## - lint the source with verbose output
	@golangci-lint run --verbose

check-godoc: ## - validate/install godoc
	which godoc || (go install golang.org/x/tools/cmd/godoc@v0.1.10)

serve-godoc: check-godoc ## - serve (web) the godocs
	godoc -http :8080

benchmark: ## benchmark the bundle.
	@go test -bench=. -run=^a -benchtime=${benchmark_time} -parallel=1 -count=${benchmark_count} ./... | tee ./tmp/go-blog-benchmarking_benchmark.log

benchmark-update: ## benchmark the bundle and update the benchmark files.
	@go test -bench=. -run=^a -benchtime=${benchmark_time} -parallel=1 -count=${benchmark_count} ./... | tee ./tmp/go-blog-benchmarking_benchmark.log | tee ${benchstat_golden_file}

check-benchstat: ## check if benchstat is installed.
	@which benchstat > /dev/null 2>&1 || go install golang.org/x/perf/cmd/benchstat@${benchstat_version}

benchstat: check-benchstat
	@benchstat ${benchstat_args} ${benchstat_golden_file} ./tmp/go-blog-benchmarking_benchmark.log 