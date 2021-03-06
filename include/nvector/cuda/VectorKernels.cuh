/*
 * -----------------------------------------------------------------
 * Programmer(s): Slaven Peles @ LLNL
 * -----------------------------------------------------------------
 * SUNDIALS Copyright Start
 * Copyright (c) 2002-2019, Lawrence Livermore National Security
 * and Southern Methodist University.
 * All rights reserved.
 *
 * See the top-level LICENSE and NOTICE files for details.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 * SUNDIALS Copyright End
 * -----------------------------------------------------------------
 */


#ifndef _VECTOR_KERNELS_CUH_
#define _VECTOR_KERNELS_CUH_

#include <limits>
#include <cuda_runtime.h>


namespace suncudavec
{

/* -----------------------------------------------------------------
 * The namespace for CUDA kernels
 *
 * Reduction CUDA kernels in nvector are based in part on "reduction"
 * example in NVIDIA Corporation CUDA Samples, and parallel reduction
 * examples in textbook by J. Cheng at al. "CUDA C Programming".
 * -----------------------------------------------------------------
 */
namespace math_kernels
{


/*
 * Sets all elements of the vector X to constant value a.
 *
 */

template <typename T, typename I>
__global__ void
setConstKernel(T a, T *X, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    X[i] = a;
  }
}


/*
 * Computes linear sum (combination) of two vectors.
 *
 */

template <typename T, typename I>
__global__ void
linearSumKernel(T a, const T *X, T b, const T *Y, T *Z, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    Z[i] = a*X[i] + b*Y[i];
  }
}


/*
 * Elementwise product of two vectors.
 *
 */

template <typename T, typename I>
__global__ void
prodKernel(const T *X, const T *Y, T *Z, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    Z[i] = X[i]*Y[i];
  }
}


/*
 * Elementwise division of two vectors.
 *
 */

template <typename T, typename I>
__global__ void
divKernel(const T *X, const T *Y, T *Z, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    Z[i] = X[i]/Y[i];
  }
}


/*
 * Scale vector with scalar value 'a'.
 *
 */

template <typename T, typename I>
__global__ void
scaleKernel(T a, const T *X, T *Z, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    Z[i] = a*X[i];
  }
}


/*
 * Stores absolute values of vector X elements into vector Z.
 *
 */

template <typename T, typename I>
__global__ void
absKernel(const T *X, T *Z, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    Z[i] = abs(X[i]);
  }
}


/*
 * Elementwise inversion.
 *
 */

template <typename T, typename I>
__global__ void
invKernel(const T *X, T *Z, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    Z[i] = 1.0/(X[i]);
  }
}


/*
 * Add constant 'c' to each vector element.
 *
 */

template <typename T, typename I>
__global__ void
addConstKernel(T a, const T *X, T *Z, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    Z[i] = a + X[i];
  }
}


/*
 * Compare absolute values of vector 'X' with constant 'c'.
 *
 */

template <typename T, typename I>
__global__ void
compareKernel(T c, const T *X, T *Z, I n)
{
  I i = blockDim.x * blockIdx.x + threadIdx.x;

  if (i < n)
  {
    Z[i] = (abs(X[i]) >= c) ? 1.0 : 0.0;
  }
}


/*
 * Sums all elements of the vector.
 *
 */
template <typename T, typename I>
__global__ void
sumReduceKernel(const T *x, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T sum = 0.0;

  // First reduction step before storing data in shared memory.
  if (i < n)
    sum = x[i];
  if (i + blockDim.x < n)
    sum += x[i+blockDim.x];
  shmem[tid] = sum;
  __syncthreads();

  // Perform reduction block-wise in shared memory.
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      sum += shmem[tid + j];
      shmem[tid] = sum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = sum;
}


/*
 * Dot product of two vectors.
 *
 */
template <typename T, typename I>
__global__ void
dotProdKernel(const T *x, const T *y, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T sum = 0.0;

  // First reduction step before storing data in shared memory.
  if (i < n)
    sum = x[i] * y[i];
  if (i + blockDim.x < n)
    sum += ( x[i+blockDim.x] * y[i+blockDim.x]);
  shmem[tid] = sum;
  __syncthreads();

  // Perform blockwise reduction in shared memory
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      sum += shmem[tid + j];
      shmem[tid] = sum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = sum;
}


/*
 * Finds max norm the vector.
 *
 */
template <typename T, typename I>
__global__ void
maxNormKernel(const T *x, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T maximum = 0.0;

  // First reduction step before storing data in shared memory.
  if (i < n)
    maximum = abs(x[i]);
  if (i + blockDim.x < n)
    maximum = max(abs(x[i+blockDim.x]), maximum);
  shmem[tid] = maximum;
  __syncthreads();

  // Perform reduction block-wise in shared memory.
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      maximum = max(shmem[tid + j], maximum);
      shmem[tid] = maximum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = maximum;
}


/*
 * Weighted L2 norm squared.
 *
 */
template <typename T, typename I>
__global__ void
wL2NormSquareKernel(const T *x, const T *w, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T sum = 0.0;

  // First reduction step before storing data in shared memory.
  if (i < n)
    sum = x[i] * w[i] * x[i] * w[i];
  if (i + blockDim.x < n)
    sum += ( x[i+blockDim.x] * w[i+blockDim.x] * x[i+blockDim.x] * w[i+blockDim.x] );

  shmem[tid] = sum;
  __syncthreads();

  // Perform reduction block-wise in shared memory.
  for (I j = blockDim.x/2; j > 0; j >>= 1)
  {
    if (tid < j) {
      sum += shmem[tid + j];
      shmem[tid] = sum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = sum;
}

/*
 * Weighted L2 norm squared with mask. Vector id specifies the mask.
 *
 */
template <typename T, typename I>
__global__ void
wL2NormSquareMaskKernel(const T *x, const T *w, const T *id, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T sum = 0.0;

  // First reduction step before storing data in shared memory.
  if (i < n && id[i] > 0.0)
    sum = x[i] * w[i] * x[i] * w[i];
  if ((i + blockDim.x < n) && (id[i+blockDim.x] > 0.0))
    sum += ( x[i+blockDim.x] * w[i+blockDim.x] * x[i+blockDim.x] * w[i+blockDim.x]);
  shmem[tid] = sum;
  __syncthreads();

  // Perform reduction block-wise in shared memory.
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      sum += shmem[tid + j];
      shmem[tid] = sum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = sum;
}

/*
 * Finds min value in the vector.
 *
 */
template <typename T, typename I>
__global__ void
findMinKernel(T MAX_VAL, const T *x, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T minimum = MAX_VAL;

  // First reduction step before storing data in shared memory.
  if (i < n)
    minimum = x[i];
  if (i + blockDim.x < n)
    minimum = min((x[i+blockDim.x]), minimum);
  shmem[tid] = minimum;
  __syncthreads();

  // Perform reduction block-wise in shared memory.
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      minimum = min(shmem[tid + j], minimum);
      shmem[tid] = minimum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = minimum;
}


/*
 * Computes L1 norm of vector
 *
 */
template <typename T, typename I>
__global__ void
L1NormKernel(const T *x, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T sum = 0.0;

  // First reduction step before storing data in shared memory.
  if (i < n)
    sum = abs(x[i]);
  if (i + blockDim.x < n)
    sum += abs(x[i+blockDim.x]);
  shmem[tid] = sum;
  __syncthreads();

  // Perform reduction block-wise in shared memory.
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      sum += shmem[tid + j];
      shmem[tid] = sum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = sum;
}

/*
 * Vector inverse  z[i] = 1/x[i] with check for zeros. Reduction is performed
 * to flag the result if any x[i] = 0.
 *
 */
template <typename T, typename I>
__global__ void
invTestKernel(const T *x, T *z, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T flag = 0.0;

  // First reduction step before storing data in shared memory.
  if (i < n) {
    if (x[i] == 0.0) {
      flag = 1.0;
    } else {
      flag = 0.0;
      z[i] = 1.0/x[i];
    }
  }

  if (i + blockDim.x < n) {
    if (x[i + blockDim.x] == 0.0) {
      flag += 1.0;
    } else {
      z[i + blockDim.x] = 1.0/x[i + blockDim.x];
    }
  }

  shmem[tid] = flag;
  __syncthreads();

  // Inverse calculation is done. Perform reduction block-wise in shared
  // to find if any x[i] = 0.
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      flag += shmem[tid + j];
      shmem[tid] = flag;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = flag;
}

/*
 * Checks if inequality constraints are satisfied. Constraint check
 * results are stored in vector 'm'. A sum reduction over all elements
 * of 'm' is performed to find if any of the constraints is violated.
 * If all constraints are satisfied sum == 0.
 *
 */
template <typename T, typename I>
__global__ void
constrMaskKernel(const T *c, const T *x, T *m, T *out, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  T sum = 0.0;

  // First reduction step before storing data in shared memory.
  if (i < n){
    // test1 = true if constraints violated
    bool test1 = (std::abs(c[i]) > 1.5 && c[i]*x[i] <= 0.0) ||
                 (std::abs(c[i]) > 0.5 && c[i]*x[i] <  0.0);
    m[i] = test1 ? 1.0 : 0.0;
    sum = m[i];
  }

  if (i + blockDim.x < n) {
    // test2 = true if constraints violated
    bool test2 = (std::abs(c[i + blockDim.x]) > 1.5 && c[i + blockDim.x]*x[i + blockDim.x] <= 0.0) ||
                 (std::abs(c[i + blockDim.x]) > 0.5 && c[i + blockDim.x]*x[i + blockDim.x] <  0.0);
    m[i+blockDim.x] = test2 ? 1.0 : 0.0;
    sum += m[i+blockDim.x];
  }

  shmem[tid] = sum;
  __syncthreads();

  // Perform reduction block-wise in shared memory.
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      sum += shmem[tid + j];
      shmem[tid] = sum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    out[blockIdx.x] = sum;
}

/*
 * Finds minimum component-wise quotient.
 *
 */
template <typename T, typename I>
__global__ void
minQuotientKernel(const T MAX_VAL, const T *num, const T *den, T *min_quotient, I n)
{
  extern __shared__ T shmem[];

  I tid = threadIdx.x;
  I i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

  // Initialize "minimum" to maximum floating point value.
  T minimum = MAX_VAL;
  const T zero = static_cast<T>(0.0);

  // Load vector quotient in the shared memory. Skip if the denominator
  // value is zero.
  if (i < n && den[i] != zero)
    minimum = num[i]/den[i];

  // First level of reduction is upon storing values to shared memory.
  if (i + blockDim.x < n && den[i + blockDim.x] != zero)
    minimum = min(num[i+blockDim.x]/den[i+blockDim.x], minimum);

  shmem[tid] = minimum;
  __syncthreads();

  // Perform reduction block-wise in shared memory.
  for (I j = blockDim.x/2; j > 0; j >>= 1) {
    if (tid < j) {
      minimum = min(shmem[tid + j], minimum);
      shmem[tid] = minimum;
    }
    __syncthreads();
  }

  // Copy reduction result for each block to global memory
  if (tid == 0)
    min_quotient[blockIdx.x] = minimum;
}


} // namespace math_kernels




template <typename T, typename I>
inline cudaError_t setConst(T a, Vector<T,I>& X)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::setConstKernel<<<grid, block, 0, stream>>>(a, X.device(), X.size());
  return cudaGetLastError();
}

template <typename T, typename I>
inline cudaError_t linearSum(T a, const Vector<T,I>& X, T b, const Vector<T,I>& Y, Vector<T,I>& Z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::linearSumKernel<<<grid, block, 0, stream>>>(a, X.device(), b, Y.device(), Z.device(), X.size());
  return cudaGetLastError();
}

template <typename T, typename I>
inline cudaError_t prod(const Vector<T,I>& X, const Vector<T,I>& Y, Vector<T,I>& Z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::prodKernel<<<grid, block, 0, stream>>>(X.device(), Y.device(), Z.device(), X.size());
  return cudaGetLastError();
}

template <typename T, typename I>
inline cudaError_t div(const Vector<T,I>& X, const Vector<T,I>& Y, Vector<T,I>& Z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::divKernel<<<grid, block, 0, stream>>>(X.device(), Y.device(), Z.device(), X.size());
  return cudaGetLastError();
}

template <typename T, typename I>
inline cudaError_t scale(T const a, const Vector<T,I>& X, Vector<T,I>& Z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::scaleKernel<<<grid, block, 0, stream>>>(a, X.device(), Z.device(), X.size());
  return cudaGetLastError();
}

template <typename T, typename I>
inline cudaError_t absVal(const Vector<T,I>& X, Vector<T,I>& Z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::absKernel<<<grid, block, 0, stream>>>(X.device(), Z.device(), X.size());
  return cudaGetLastError();
}

template <typename T, typename I>
inline cudaError_t inv(const Vector<T,I>& X, Vector<T,I>& Z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::invKernel<<<grid, block, 0, stream>>>(X.device(), Z.device(), X.size());
  return cudaGetLastError();
}

template <typename T, typename I>
inline cudaError_t addConst(T const a, const Vector<T,I>& X, Vector<T,I>& Z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::addConstKernel<<<grid, block, 0, stream>>>(a, X.device(), Z.device(), X.size());
  return cudaGetLastError();
}


template <typename T, typename I>
inline cudaError_t compare(T const c, const Vector<T,I>& X, Vector<T,I>& Z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = X.partStream();
  const I grid                = p.grid();
  const unsigned block        = p.block();
  const cudaStream_t stream   = p.stream();

  math_kernels::compareKernel<<<grid, block, 0, stream>>>(c, X.device(), Z.device(), X.size());
  return cudaGetLastError();
}


template <typename T, typename I>
inline T dotProd(const Vector<T,I>& x, const Vector<T,I>& y)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = x.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::dotProdKernel<T,I><<<grid, block, shMemSize, stream>>>(x.device(), y.device(), p.devBuffer(), x.size());

  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // Rerun reduction kernel
    math_kernels::sumReduceKernel<T,I><<<grid, block, shMemSize, stream>>>(p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    gpu_result += p.hostBuffer()[i];
  }
  return gpu_result;
}

template <typename T, typename I>
inline T maxNorm(const Vector<T,I>& x)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = x.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::maxNormKernel<T,I><<<grid, block, shMemSize, stream>>>(x.device(), p.devBuffer(), x.size());

  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // (Re)run reduction kernel
    math_kernels::maxNormKernel<T,I><<<grid, block, shMemSize, stream>>>(p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    if (p.hostBuffer()[i] > gpu_result)
      gpu_result = p.hostBuffer()[i];
  }
  return gpu_result;
}

template <typename T, typename I>
inline T wL2NormSquareMask(const Vector<T,I>& x, const Vector<T,I>& w, const Vector<T,I>& id)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = x.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::wL2NormSquareMaskKernel<T,I><<<grid, block, shMemSize, stream>>>(x.device(), w.device(), id.device(), p.devBuffer(), x.size());

  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // (Re)run reduction kernel
    math_kernels::sumReduceKernel<T,I><<<grid, block, shMemSize, stream>>>(p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    gpu_result += p.hostBuffer()[i];
  }
  return gpu_result;
}

template <typename T, typename I>
inline T findMin(const Vector<T,I>& x)
{
  T maxVal = std::numeric_limits<T>::max();

  // Set partitioning
  ThreadPartitioning<T, I>& p = x.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::findMinKernel<T,I><<<grid, block, shMemSize, stream>>>(maxVal, x.device(), p.devBuffer(), x.size());

  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // Rerun reduction kernel
    math_kernels::findMinKernel<T,I><<<grid, block, shMemSize, stream>>>(maxVal, p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    if (p.hostBuffer()[i] < gpu_result)
      gpu_result = p.hostBuffer()[i];
  }
  return gpu_result;
}


template <typename T, typename I>
inline T wL2NormSquare(const Vector<T,I>& x, const Vector<T,I>& y)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = x.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::wL2NormSquareKernel<T,I><<<grid, block, shMemSize, stream>>>(x.device(), y.device(), p.devBuffer(), x.size());

  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // Rerun reduction kernel
    math_kernels::sumReduceKernel<T,I><<<grid, block, shMemSize, stream>>>(p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    gpu_result += p.hostBuffer()[i];
  }
  return (gpu_result);
}


template <typename T, typename I>
inline T L1Norm(const Vector<T,I>& x)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = x.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::L1NormKernel<T,I><<<grid, block, shMemSize, stream>>>(x.device(), p.devBuffer(), x.size());

  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // Rerun reduction kernel
    math_kernels::sumReduceKernel<T,I><<<grid, block, shMemSize, stream>>>(p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    gpu_result += p.hostBuffer()[i];
  }
  return gpu_result;
}


template <typename T, typename I>
inline T invTest(const Vector<T,I>& x, Vector<T,I>& z)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = x.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::invTestKernel<T,I><<<grid, block, shMemSize, stream>>>(x.device(), z.device(), p.devBuffer(), x.size());

  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // Rerun reduction kernel
    math_kernels::sumReduceKernel<T,I><<<grid, block, shMemSize, stream>>>(p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    gpu_result += p.hostBuffer()[i];
  }
  return gpu_result;
}


template <typename T, typename I>
inline T constrMask(const Vector<T,I>& c, const Vector<T,I>& x, Vector<T,I>& m)
{
  // Set partitioning
  ThreadPartitioning<T, I>& p = x.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::constrMaskKernel<T,I><<<grid, block, shMemSize, stream>>>(c.device(), x.device(), m.device(), p.devBuffer(), x.size());

  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // Rerun reduction kernel
    math_kernels::sumReduceKernel<T,I><<<grid, block, shMemSize, stream>>>(p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    gpu_result += p.hostBuffer()[i];
  }
  return gpu_result;
}


template <typename T, typename I>
inline T minQuotient(const Vector<T,I>& num, const Vector<T,I>& den)
{
  // Starting value for min reduction
  const T maxVal = std::numeric_limits<T>::max();

  // Set partitioning
  ThreadPartitioning<T, I>& p = num.partReduce();
  unsigned grid               = p.grid();
  unsigned block              = p.block();
  unsigned shMemSize          = p.shmem();
  const cudaStream_t stream   = p.stream();

  math_kernels::minQuotientKernel<T,I><<<grid, block, shMemSize, stream>>>(maxVal, num.device(), den.device(), p.devBuffer(), num.size());

  // All quotients are computed by now. Find the minimum.
  unsigned n = grid;
  unsigned nmax = 2*block;
  while (n > nmax)
  {
    // Recompute partitioning
    p.calcPartitioning(n, grid, block, shMemSize);

    // Rerun reduction kernel
    math_kernels::findMinKernel<T,I><<<grid, block, shMemSize, stream>>>(maxVal, p.devBuffer(), p.devBuffer(), n);
    n = grid;
  }

  // Finish reduction on CPU if there are less than two blocks of data left.
  p.copyFromDevBuffer(n);

  T gpu_result = p.hostBuffer()[0];
  for (unsigned int i=1; i<n; i++)
  {
    if (p.hostBuffer()[i] < gpu_result)
      gpu_result = p.hostBuffer()[i];
  }
  return gpu_result;
}


} // namespace nvec


#endif // _VECTOR_KERNELS_CUH_
