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
  DOCKER_BUILDKIT=1 docker build -t hiennguyen9874/deepstream-tensorrt:6.0.1-devel \
      --build-arg DS_VERSION=6.0.1 \
      --build-arg ARCH=x86_64 \
      --build-arg TRT_OSS_CHECKOUT_TAG=release/8.2 \
      --build-arg TENSORRT_REPO=https://github.com/hiennguyen9874/TensorRT \
      -f Dockerfile.devel \
      .
  ```
- Push: `docker push hiennguyen9874/deepstream-tensorrt:6.0.1-devel`

### Iot

- Build:
  ```
  DOCKER_BUILDKIT=1 docker build -t hiennguyen9874/deepstream-tensorrt:6.0.1-iot \
      --build-arg DS_VERSION=6.0.1 \
      --build-arg ARCH=x86_64 \
      --build-arg TRT_OSS_CHECKOUT_TAG=release/8.2 \
      --build-arg TENSORRT_REPO=https://github.com/hiennguyen9874/TensorRT \
      -f Dockerfile.iot \
      .
  ```
- Push: `docker push hiennguyen9874/deepstream-tensorrt:6.0.1-iot`
