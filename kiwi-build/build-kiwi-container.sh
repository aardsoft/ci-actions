#!/bin/bash
set -xe

if [ -z "${target_dir}" ]; then
    target_dir=`mktemp -d`
fi

cd ${image_dir}
_arch=`uname -m`
_target_arch=${target_arch:-${_arch}}

# for now we just hope that for multiple kiwi files the first one is what we want
_kiwi_file=(*.kiwi)
_image_specification=`xmllint --xpath 'string(//specification)' ${_kiwi_file}`
_image_version=`xmllint --xpath 'string(//version)' ${_kiwi_file}`
_image_name=`xmllint --xpath 'string(//image/@name)' ${_kiwi_file}`
_container_tag=`xmllint --xpath 'string(//containerconfig/@tag)' ${_kiwi_file}`
_container_name=`xmllint --xpath 'string(//containerconfig/@name)' ${_kiwi_file}`
_derived_container=`xmllint --xpath 'string(//type/@derived_from)' ${_kiwi_file}`

if [ -z "${_image_cache}" ]; then
    _image_cache=/tmp/image_cache
fi

mkdir -p "${_image_cache}"
if [ -n "${_derived_container}" ]; then
    _derived_file=`basename ${_derived_container}`
    _derived_file_base=`echo ${_derived_file} | awk -F ':' '{print $1}'`
    _derived_file_tag=`echo ${_derived_file} | awk -F ':' '{print $2}'`
    _derived_file_path="${_image_cache}/${_derived_file_base}.${_target_arch}-${_derived_file_tag}.docker.tar"

    if [ -f "${_derived_file_path}" ]; then
        echo "exists"
    else
        podman pull "${_derived_container}"
        podman save "${_derived_container}" -o "${_derived_file_path}"
    fi
fi

sudo $TRACE kiwi-ng `if [ -n "${kiwi_debug}" ]; then echo -n "--debug"; fi` `if [ -n "${kiwi_profile}" ]; then echo -n "--profile ${kiwi_profile}"; fi` `if [ "${_target_arch}" != "${_arch}" ]; then echo -n "--target-arch ${_target_arch}"; fi` system build --description "`pwd`" `if [ -n "${kiwi_extra_args}" ]; then echo -n "${kiwi_extra_args}"; fi` \
     --set-repo ${repository} `for r in $extra_repos; do echo -n " --add-repo $r "; done` \
     --target-dir ${target_dir}/${_image_name} `if [ -n "${_derived_file_path}" ]; then echo -n " --set-container-derived-from file://${_derived_file_path} "; fi` \
     --add-container-label="name=${_container_name}" --set-container-tag="${_container_tag}"
if [ -f ${target_dir}/${_image_name}/${_image_name}.${_target_arch}-${_image_version}.docker.tar ]; then
    _container_archive=${target_dir}/${_image_name}/${_image_name}.${_target_arch}-${_image_version}.docker.tar
elif [ -f ${target_dir}/${_image_name}/${_image_name}.${_target_arch}-${_image_version}.docker.tar.xz ]; then
    _container_archive=${target_dir}/${_image_name}/${_image_name}.${_target_arch}-${_image_version}.docker.tar.xz
else
    echo "Can't locate container archive"
    exit 1
fi

echo "container_name=${_container_name}" >> ${GITHUB_OUTPUT}
echo "container_tag=${_container_tag}" >> ${GITHUB_OUTPUT}

podman load -i ${_container_archive}
if [ -n "${arch_suffix}" ]; then
    # Arch-specific push only; manifest creation handles :latest and :git_tag
    podman push ${_container_name}:${_container_tag} ${_container_name}:${_container_tag}-${arch_suffix}
else
    podman push ${_container_name}:${_container_tag}
    podman push ${_container_name}:${_container_tag} ${_container_name}:latest
    if [ -n "${git_tag}" ]; then
        podman push ${_container_name}:${_container_tag} ${_container_name}:${git_tag}
    fi
fi
sudo mv ${_container_archive} ${_image_cache}/
