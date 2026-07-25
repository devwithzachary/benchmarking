# System Benchmarking Tools

Welcome to my collection of system benchmarking scripts. This repository contains tools to test CPU, GPU, storage, and battery performance across Linux and macOS systems. It also includes a web dashboard to easily compare the results.

**View the live benchmark results here:** [https://devwithzachary.github.io/benchmarking/](https://devwithzachary.github.io/benchmarking/)

## What is included?

### 1. benchmark.sh
An automated system benchmarking script for Linux and macOS. It handles installing the required dependencies via standard package managers and runs a full suite of tests.
* **Geekbench 7** (CPU and GPU Compute)
* **Geekbench AI** (CPU and GPU Compute)

The script automatically formats the final output into a clean JSON file ready to be added to the web dashboard.

### 2. battery_test.sh
A background script for Linux laptops that monitors your battery life while you run normal tasks like watching a YouTube video. It logs the battery percentage and elapsed time to a CSV file every 60 seconds. It forces a disk sync on every write to ensure data is safely stored when the machine suddenly powers off.

### 3. Web Dashboard (index.html)
A static web page that reads from `benchmarks.json` to display a sortable table of all your tested devices. It includes clickable links to fetch scores from the Geekbench browser.

## How to run the system benchmark

1. Clone this repository to your machine:
   ```bash
   git clone [https://github.com/devwithzachary/benchmarking.git](https://github.com/devwithzachary/benchmarking.git)
   cd benchmarking