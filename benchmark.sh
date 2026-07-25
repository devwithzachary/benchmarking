#!/bin/bash

OUTPUT_FILE="benchmark_$(hostname)_$(date +%Y%m%d).json"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

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
else
    OS_INFO=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Unknown Linux")
    CPU_INFO=$(grep -m1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | xargs)
    GPU_INFO=$(command -v lspci >/dev/null && lspci | grep -iE 'vga|3d|display' | sed 's/.*: //' | xargs || echo "Not detected or lspci missing")
    MEM_INFO=$(free -h | awk '/^Mem:/ {print $2}')
    THREADS=$(nproc)
    IO_ENGINE="libaio"
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
        if [ -x "/Applications/Geekbench 7.app/Contents/MacOS/geekbench7" ]; then echo "/Applications/Geekbench 7.app/Contents/MacOS/geekbench7"
        elif [ -x "$DIR/Geekbench-7-macOS/Geekbench 7.app/Contents/MacOS/geekbench7" ]; then echo "$DIR/Geekbench-7-macOS/Geekbench 7.app/Contents/MacOS/geekbench7"
        elif command -v geekbench7 >/dev/null 2>&1; then echo "geekbench7"
        else
            curl -sL -o "$DIR/Geekbench-7-macOS.zip" "https://cdn.geekbench.com/Geekbench-7.0.0-macOS.zip" >/dev/null 2>&1
            unzip -q "$DIR/Geekbench-7-macOS.zip" -d "$DIR/Geekbench-7-macOS" >/dev/null 2>&1
            rm -f "$DIR/Geekbench-7-macOS.zip"
            [ -x "$DIR/Geekbench-7-macOS/Geekbench 7.app/Contents/MacOS/geekbench7" ] && echo "$DIR/Geekbench-7-macOS/Geekbench 7.app/Contents/MacOS/geekbench7" || echo ""
        fi
    else
        if [ -x "$DIR/geekbench7" ]; then echo "$DIR/geekbench7"
        elif ls "$DIR"/Geekbench-7*-Linux/geekbench7 1> /dev/null 2>&1; then ls "$DIR"/Geekbench-7*-Linux/geekbench7 | head -n 1
        elif command -v geekbench7 >/dev/null 2>&1; then echo "geekbench7"
        else
            wget -qO- https://cdn.geekbench.com/Geekbench-7.0.0-Linux.tar.gz | tar xvz -C "$DIR" >/dev/null 2>&1
            ls "$DIR"/Geekbench-7*-Linux/geekbench7 1> /dev/null 2>&1 && ls "$DIR"/Geekbench-7*-Linux/geekbench7 | head -n 1 || echo ""
        fi
    fi
}

resolve_geekbench_ai() {
    if [ "$OS_TYPE" = "Darwin" ]; then
        if [ -x "/Applications/Geekbench AI.app/Contents/MacOS/geekbenchAI" ]; then echo "/Applications/Geekbench AI.app/Contents/MacOS/geekbenchAI"
        elif [ -x "$DIR/GeekbenchAI-macOS/Geekbench AI.app/Contents/MacOS/geekbenchAI" ]; then echo "$DIR/GeekbenchAI-macOS/Geekbench AI.app/Contents/MacOS/geekbenchAI"
        elif command -v geekbenchAI >/dev/null 2>&1; then echo "geekbenchAI"
        else
            curl -sL -o "$DIR/GeekbenchAI-macOS.zip" "https://cdn.geekbench.com/GeekbenchAI-1.7.0-macOS.zip" >/dev/null 2>&1
            unzip -q "$DIR/GeekbenchAI-macOS.zip" -d "$DIR/GeekbenchAI-macOS" >/dev/null 2>&1
            rm -f "$DIR/GeekbenchAI-macOS.zip"
            [ -x "$DIR/GeekbenchAI-macOS/Geekbench AI.app/Contents/MacOS/geekbenchAI" ] && echo "$DIR/GeekbenchAI-macOS/Geekbench AI.app/Contents/MacOS/geekbenchAI" || echo ""
        fi
    else
        if [ -x "$DIR/geekbenchAI" ]; then echo "$DIR/geekbenchAI"
        elif ls "$DIR"/GeekbenchAI-*-Linux/geekbenchAI 1> /dev/null 2>&1; then ls "$DIR"/GeekbenchAI-*-Linux/geekbenchAI | head -n 1
        elif command -v geekbenchAI >/dev/null 2>&1; then echo "geekbenchAI"
        else
            wget -qO- https://cdn.geekbench.com/GeekbenchAI-1.7.0-Linux.tar.gz | tar xvz -C "$DIR" >/dev/null 2>&1
            ls "$DIR"/GeekbenchAI-*-Linux/geekbenchAI 1> /dev/null 2>&1 && ls "$DIR"/GeekbenchAI-*-Linux/geekbenchAI | head -n 1 || echo ""
        fi
    fi
}

FIO_CMD=$(resolve_tool fio)
GB_CMD=$(resolve_geekbench)
GBAI_CMD=$(resolve_geekbench_ai)

# Default values
FIO_READ="null"
FIO_WRITE="null"
GB_CPU_URL="null"
GB_GPU_URL="null"
GBAI_CPU_URL="null"
GBAI_GPU_URL="null"

echo "Running FIO Storage Test..."
if [ -n "$FIO_CMD" ]; then
    $FIO_CMD --name=randrw_test --filename=$DIR/fio_test_file --size=1G --direct=1 --rw=randrw --bs=4k --ioengine=$IO_ENGINE --iodepth=64 --runtime=30 --time_based --group_reporting > /tmp/fio_temp.txt 2>&1
    
    AWK_MBPS='function get_mbps(str) { val=str+0; if(str~/MiB/||str~/mib/)return val*1.048576; if(str~/KiB/||str~/kib/)return (val*1.024)/1000; if(str~/GiB/||str~/gib/)return val*1073.74; if(str~/[kK]B/)return val/1000; if(str~/GB/)return val*1000; return val; }'
    
    FIO_READ=$($FIO_CMD --version >/dev/null 2>&1 && awk "$AWK_MBPS tolower(\$0) ~ /read *:/ { match(\$0, /[bB][wW]=[^, )]+/); bw=substr(\$0, RSTART+3, RLENGTH-3); printf \"%.2f\", get_mbps(bw); exit }" /tmp/fio_temp.txt || echo "null")
    FIO_WRITE=$($FIO_CMD --version >/dev/null 2>&1 && awk "$AWK_MBPS tolower(\$0) ~ /write *:/ { match(\$0, /[bB][wW]=[^, )]+/); bw=substr(\$0, RSTART+3, RLENGTH-3); printf \"%.2f\", get_mbps(bw); exit }" /tmp/fio_temp.txt || echo "null")
    
    rm -f $DIR/fio_test_file /tmp/fio_temp.txt
fi

echo "Running Geekbench 7 CPU Test..."
if [ -n "$GB_CMD" ]; then
    "$GB_CMD" > /tmp/gb_temp.txt 2>&1
    TEMP_CPU_URL=$(grep "https://browser.geekbench.com" /tmp/gb_temp.txt | grep -v "claim" | xargs)
    if [ -n "$TEMP_CPU_URL" ]; then
        GB_CPU_URL="\"$TEMP_CPU_URL\""
    fi
    
    echo "Running Geekbench 7 GPU Test..."
    "$GB_CMD" --gpu > /tmp/gb_gpu_temp.txt 2>&1
    TEMP_GPU_URL=$(grep "https://browser.geekbench.com" /tmp/gb_gpu_temp.txt | grep -v "claim" | xargs)
    if [ -n "$TEMP_GPU_URL" ]; then
        GB_GPU_URL="\"$TEMP_GPU_URL\""
    fi
    
    rm -f /tmp/gb_temp.txt /tmp/gb_gpu_temp.txt
fi

echo "Running Geekbench AI CPU Test..."
if [ -n "$GBAI_CMD" ]; then
    "$GBAI_CMD" > /tmp/gbai_temp.txt 2>&1
    TEMP_AI_CPU_URL=$(grep "https://browser.geekbench.com" /tmp/gbai_temp.txt | grep -v "claim" | xargs)
    if [ -n "$TEMP_AI_CPU_URL" ]; then
        GBAI_CPU_URL="\"$TEMP_AI_CPU_URL\""
    fi
    
    echo "Running Geekbench AI GPU Test..."
    "$GBAI_CMD" --gpu > /tmp/gbai_gpu_temp.txt 2>&1
    TEMP_AI_GPU_URL=$(grep "https://browser.geekbench.com" /tmp/gbai_gpu_temp.txt | grep -v "claim" | xargs)
    if [ -n "$TEMP_AI_GPU_URL" ]; then
        GBAI_GPU_URL="\"$TEMP_AI_GPU_URL\""
    fi
    
    rm -f /tmp/gbai_temp.txt /tmp/gbai_gpu_temp.txt
fi

echo "Generating JSON Output..."

# Write JSON to file
cat <<EOF > "$OUTPUT_FILE"
{
  "hostname": "$HOSTNAME_VAL",
  "os": "$OS_INFO",
  "cpu": "$CPU_INFO",
  "ram": "$MEM_INFO",
  "gbCpuUrl": $GB_CPU_URL,
  "gbGpuUrl": $GB_GPU_URL,
  "gbSingle": null,
  "gbMulti": null,
  "gbGpu": null,
  "gbAiCpuUrl": $GBAI_CPU_URL,
  "gbAiGpuUrl": $GBAI_GPU_URL,
  "gbAiCpu": null,
  "gbAiGpu": null,
  "fioRead": $FIO_READ,
  "fioWrite": $FIO_WRITE
}
EOF

echo "Done! Output saved to $OUTPUT_FILE"
cat "$OUTPUT_FILE"