#!/bin/bash

OUTPUT_FILE="benchmark_$(hostname)_$(date +%Y%m%d).json"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

DEBUG_MODE=0

# Parse arguments
for arg in "$@"; do
    case $arg in
        --debug)
        DEBUG_MODE=1
        shift
        ;;
    esac
done

debug_log() {
    if [ "$DEBUG_MODE" -eq 1 ]; then
        echo "DEBUG: $1"
    fi
}

echo "Starting System Benchmark..."
echo "This will take a few minutes. Results will be saved to $OUTPUT_FILE"

OS_TYPE=$(uname -s)

# Gather system information
if [ "$OS_TYPE" = "Darwin" ]; then
    OS_INFO="macOS $(sw_vers -productVersion)"
    CPU_INFO=$(sysctl -n machdep.cpu.brand_string | xargs)
    GPU_INFO=$(system_profiler SPDisplaysDataType | grep -i "Chipset Model" | awk -F: '{print $2}' | xargs || echo "Not detected")
    MEM_INFO="$(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
    THREADS=$(sysctl -n hw.logicalcpu)
    IO_ENGINE="posixaio"
    FIO_OPTS="--fallocate=none"
else
    OS_INFO=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown Linux")
    CPU_INFO=$(grep -m1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | xargs)
    GPU_INFO=$(command -v lspci >/dev/null && lspci | grep -iE 'vga|3d|display' | sed 's/.*: //' | xargs || echo "Not detected or lspci missing")
    MEM_INFO=$(free -h | awk '/^Mem:/ {print $2}')
    THREADS=$(nproc)
    IO_ENGINE="libaio"
    FIO_OPTS="--direct=1"
fi

HOSTNAME_VAL=$(hostname)

# Install helpers
install_tool() {
    local tool=$1
    if [ "$OS_TYPE" = "Darwin" ]; then
        command -v brew >/dev/null 2>&1 && brew install $tool >/dev/null || return 1
    else
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update >/dev/null 2>&1 || true
            sudo apt-get install -y $tool >/dev/null
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y $tool >/dev/null
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy --noconfirm $tool >/dev/null
        else
            return 1
        fi
    fi
}

resolve_tool() {
    local tool=$1
    if [ -x "$DIR/$tool" ]; then echo "$DIR/$tool"
    elif command -v "$tool" >/dev/null 2>&1; then echo "$tool"
    else
        install_tool "$tool"
        command -v "$tool" >/dev/null 2>&1 && echo "$tool" || echo ""
    fi
}

resolve_geekbench() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        echo "$DIR/Geekbench-7-macOS/Geekbench 7.app/Contents/MacOS/Geekbench 7"
    else
        echo "$DIR/Geekbench-7.0.0-Linux/geekbench7"
    fi 
}

resolve_geekbench_ai() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        echo "$DIR/GeekbenchAI-macOS/Geekbench AI.app/Contents/MacOS/Geekbench AI"
    else
        echo "$DIR/GeekbenchAI-1.7.0-Linux/geekbenchAI"
    fi
}

debug_log "Resolving tool paths..."
GB_CMD=$(resolve_geekbench)
GBAI_CMD=$(resolve_geekbench_ai)

debug_log "Resolved Geekbench 7 path -> '$GB_CMD'"
debug_log "Resolved Geekbench AI path -> '$GBAI_CMD'"

# Default values
GB_CPU_URL="null"
GB_GPU_URL="null"
GBAI_CPU_URL="null"
GBAI_GPU_URL="null"
GBAI_NPU_URL="null"

echo "Running Geekbench 7 CPU Test..."
if [ -n "$GB_CMD" ]; then
    debug_log "Running command -> \"$GB_CMD\""
    "$GB_CMD" > /tmp/gb_temp.txt 2>&1
    
    TEMP_CPU_URL=$(grep "https://browser.geekbench.com" /tmp/gb_temp.txt | grep -v "claim" | xargs)
    [ -n "$TEMP_CPU_URL" ] && GB_CPU_URL="\"$TEMP_CPU_URL\""
    
    echo "Running Geekbench 7 GPU Test..."
    debug_log "Running command -> \"$GB_CMD\" --gpu"
    "$GB_CMD" --gpu > /tmp/gb_gpu_temp.txt 2>&1
    
    TEMP_GPU_URL=$(grep "https://browser.geekbench.com" /tmp/gb_gpu_temp.txt | grep -v "claim" | xargs)
    [ -n "$TEMP_GPU_URL" ] && GB_GPU_URL="\"$TEMP_GPU_URL\""
    
    if [ "$DEBUG_MODE" -eq 0 ]; then
        rm -f /tmp/gb_temp.txt /tmp/gb_gpu_temp.txt
    fi
fi

echo "Running Geekbench AI CPU Test..."
if [ -n "$GBAI_CMD" ]; then
    debug_log "Running command -> \"$GBAI_CMD\""
    "$GBAI_CMD" > /tmp/gbai_temp.txt 2>&1
    TEMP_AI_CPU_URL=$(grep "https://browser.geekbench.com" /tmp/gbai_temp.txt | grep -v "claim" | xargs)
    [ -n "$TEMP_AI_CPU_URL" ] && GBAI_CPU_URL="\"$TEMP_AI_CPU_URL\""
    
    echo "Running Geekbench AI GPU Test..."
    debug_log "Running command -> \"$GBAI_CMD\" --gpu"
    "$GBAI_CMD" --gpu > /tmp/gbai_gpu_temp.txt 2>&1
    TEMP_AI_GPU_URL=$(grep "https://browser.geekbench.com" /tmp/gbai_gpu_temp.txt | grep -v "claim" | xargs)
    [ -n "$TEMP_AI_GPU_URL" ] && GBAI_GPU_URL="\"$TEMP_AI_GPU_URL\""

    echo "Running Geekbench AI NPU Test..."
    debug_log "Running command -> \"$GBAI_CMD\" --npu"
    "$GBAI_CMD" --npu > /tmp/gbai_npu_temp.txt 2>&1
    TEMP_AI_NPU_URL=$(grep "https://browser.geekbench.com" /tmp/gbai_npu_temp.txt | grep -v "claim" | xargs)
    [ -n "$TEMP_AI_NPU_URL" ] && GBAI_NPU_URL="\"$TEMP_AI_NPU_URL\""
    
    if [ "$DEBUG_MODE" -eq 0 ]; then
        rm -f /tmp/gbai_temp.txt /tmp/gbai_gpu_temp.txt /tmp/gbai_npu_temp.txt
    fi
fi

echo "Generating JSON Output..."

cat <<EOF > "$OUTPUT_FILE"
{
  "hostname": "$HOSTNAME_VAL",
  "os": "$OS_INFO",
  "cpu": "$CPU_INFO",
  "gpu": "$GPU_INFO",
  "ram": "$MEM_INFO",
  "gbCpuUrl": $GB_CPU_URL,
  "gbGpuUrl": $GB_GPU_URL,
  "gbSingle": null,
  "gbMulti": null,
  "gbGpu": null,
  "gbAiCpuUrl": $GBAI_CPU_URL,
  "gbAiGpuUrl": $GBAI_GPU_URL,
  "gbAiNpuUrl": $GBAI_NPU_URL,
  "gbAiCpuSingle": null,
  "gbAiCpuHalf": null,
  "gbAiCpuQuant": null,
  "gbAiGpuSingle": null,
  "gbAiGpuHalf": null,
  "gbAiGpuQuant": null,
  "gbAiNpuSingle": null,
  "gbAiNpuHalf": null,
  "gbAiNpuQuant": null
}
EOF

echo "Done! Output saved to $OUTPUT_FILE"
cat "$OUTPUT_FILE"