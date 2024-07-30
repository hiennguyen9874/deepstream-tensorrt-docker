# Custom docker deepstream

## Additional

- opencv
- hiredis
- [Civetweb](https://github.com/civetweb/civetweb)
- [redis-plus-plus](https://github.com/sewenew/redis-plus-plus.git)
- [CMake](https://github.com/Kitware/CMake)
- [TensorRT](https://github.com/hiennguyen9874/TensorRT)

## Build

### Devel

- Build:
  ```
  DOCKER_BUILDKIT=1 docker build -t hiennguyen9874/deepstream-tensorrt:6.3-devel \
      --build-arg DS_VERSION=6.3 \
      --build-arg ARCH=x86_64 \
      --build-arg TRT_OSS_CHECKOUT_TAG=release/8.5 \
      --build-arg TENSORRT_REPO=https://github.com/hiennguyen9874/TensorRT \
      --target devel \
      -f Dockerfile \
      .
  ```
- Push: `docker push hiennguyen9874/deepstream-tensorrt:6.3-devel`

### Samples

- Build:
  ```
  DOCKER_BUILDKIT=1 docker build -t hiennguyen9874/deepstream-tensorrt:6.3-samples \
      --build-arg DS_VERSION=6.3 \
      --build-arg ARCH=x86_64 \
      --build-arg TRT_OSS_CHECKOUT_TAG=release/8.5 \
      --build-arg TENSORRT_REPO=https://github.com/hiennguyen9874/TensorRT \
      --target samples \
      -f Dockerfile \
      .
  ```
- Push: `docker push hiennguyen9874/deepstream-tensorrt:6.3-samples`

### Base

- Build:
  ```
  DOCKER_BUILDKIT=1 docker build -t hiennguyen9874/deepstream-tensorrt:6.3-base \
      --build-arg DS_VERSION=6.3 \
      --build-arg ARCH=x86_64 \
      --build-arg TRT_OSS_CHECKOUT_TAG=release/8.5 \
      --build-arg TENSORRT_REPO=https://github.com/hiennguyen9874/TensorRT \
      --target base \
      -f Dockerfile \
      .
  ```
- Push: `docker push hiennguyen9874/deepstream-tensorrt:6.3-base`
