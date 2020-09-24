#!/bin/bash
#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

java_xmx_mb=$(echo '
    import os
    wf_memory_gb = float(os.environ.get("WF_MEMORY_GB", 1))
    java_xmx_mb = max(1000, wf_memory_gb * 1000 * 0.8)
    print(int(java_xmx_mb))
' | python -c 'import sys, textwrap; exec(textwrap.dedent(sys.stdin.read()).strip())')

echo "-Xmx${java_xmx_mb}m -XX:+UseSerialGC -XX:CICompilerCount=2"
