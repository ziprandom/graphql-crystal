#!/bin/sh
crystal build --release benchmark/compare_benchmarks.cr
./compare_benchmarks
