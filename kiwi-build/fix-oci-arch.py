#!/usr/bin/env python3
"""Patch architecture (and optional variant) in a Docker-format image tar.

kiwi sets the host architecture in the OCI config even for cross-arch builds.
This script rewrites the config JSON in-place.

Usage: fix-oci-arch.py <tar-file> <arch> [variant]
  arch    OCI architecture name, e.g. arm64, amd64
  variant optional OCI variant, e.g. v8
"""
import io, json, os, sys, tarfile

tar_file = sys.argv[1]
arch     = sys.argv[2]
variant  = sys.argv[3] if len(sys.argv) > 3 else None
tmp_file = tar_file + '.tmp'

with tarfile.open(tar_file, 'r') as tin:
    manifest    = json.loads(tin.extractfile('manifest.json').read())
    config_name = manifest[0]['Config']
    config      = json.loads(tin.extractfile(config_name).read())

    config['architecture'] = arch
    if variant:
        config['variant'] = variant
    elif 'variant' in config:
        del config['variant']

    new_config = json.dumps(config).encode()

    with tarfile.open(tmp_file, 'w') as tout:
        for member in tin.getmembers():
            if member.name == config_name:
                info      = tarfile.TarInfo(name=config_name)
                info.size = len(new_config)
                tout.addfile(info, io.BytesIO(new_config))
            else:
                tout.addfile(member, tin.extractfile(member))

os.replace(tmp_file, tar_file)
