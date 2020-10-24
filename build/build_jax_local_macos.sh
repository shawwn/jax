#!/bin/bash
set -uex
tensorflow_commit="$(cat WORKSPACE | egrep 'strip_prefix.*tensorflow' | egrep -o '[a-f0-9]+\b')"
if [ ! -d tensorflow ]
then
  mkdir tensorflow
  cd tensorflow
  git init
  git remote add origin https://github.com/tensorflow/tensorflow
  git fetch origin "$tensorflow_commit" --depth 1
  git reset --hard FETCH_HEAD
  cd ..
else
  echo "Ensure tensorflow/ is at commit $tensorflow_commit"
fi

if [ ! -f .bazelrc ]
then
tee .bazelrc <<EOF
# Flag to enable remote config
common --experimental_repo_remote_exec

build --repo_env PYTHON_BIN_PATH="/usr/local/bin/python3"
build --python_path="/usr/local/bin/python3"
build --repo_env TF_NEED_CUDA="0"
build --action_env TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0"
build --distinct_host_configuration=false
build --copt=-Wno-sign-compare
build -c opt
build:opt --copt=-march=native
build:opt --host_copt=-march=native
build:mkl_open_source_only --define=tensorflow_mkldnn_contraction_kernel=1

# Sets the default Apple platform to macOS.
build --apple_platform_type=macos
build --macos_minimum_os=10.9

# Make Bazel print out all options from rc files.
build --announce_rc

build --define open_source_build=true

# Disable enabled-by-default TensorFlow features that we don't care about.
build --define=no_aws_support=true
build --define=no_gcp_support=true
build --define=no_hdfs_support=true
build --define=no_kafka_support=true
build --define=no_ignite_support=true
build --define=grpc_no_ares=true

build:cuda --crosstool_top=@local_config_cuda//crosstool:toolchain
build:cuda --define=using_cuda=true --define=using_cuda_nvcc=true

build --spawn_strategy=standalone
build --strategy=Genrule=standalone

build --cxxopt=-std=c++14
build --host_cxxopt=-std=c++14

# Suppress all warning messages.
build:short_logs --output_filter=DONT_MATCH_ANYTHING
EOF
fi


set -ex
BAZEL_ROOT=/Volumes/birdie
[ ! -d "$BAZEL_ROOT" ] && 1>&2 echo "Set BAZEL_ROOT to somewhere with ~50GB free" && exit 1
DISK_CACHE="$BAZEL_ROOT"/bazel-root/bazel-disk-cache
OUTPUT_BASE="$BAZEL_ROOT"/bazel-root/jax-nightly

set -x

(cd build; bazel --output_base "$OUTPUT_BASE" run --verbose_failures=true --disk_cache "$DISK_CACHE" --config=short_logs --config=mkl_open_source_only :install_xla_in_source_tree "$(pwd)")

python3 setup.py bdist_wheel
