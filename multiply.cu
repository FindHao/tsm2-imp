/*
  multiply.cu -- Matrix multiplication testbench - by Cody Rivera
*/

#include <cstdio>
#include <cmath>
#include <cstdlib>
#include "cuda_runtime.h"
#include "cublas_v2.h"

#include "multiply.cuh"

#include "kernels_mtsm2_2.cuh"


#define EPS 10e-3
#define MAX_TILES 255

/*
  Helper functions
 */


#include "parameters.cuh"



// Based on https://randomascii.wordpress.com/2012/02/25/comparing-floating-point-numbers-2012-edition/
bool approxEqual(double A, double B,
                 double maxRelDiff = EPS)
{
    // Calculate the difference.
    double diff = fabs(A - B);
    A = fabs(A);
    B = fabs(B);
    // Find the largest
    double largest = (B > A) ? B : A;

    if (diff <= largest * maxRelDiff)
        return true;
    return false;
}


template<typename FloatType>
bool matrixCompare(const FloatType* A, const FloatType* B,
                   unsigned int m, unsigned int n,
                   unsigned int& iFail, unsigned int& jFail)
{
    FloatType aVal, bVal;
    bool b = true;
    // Cache-friendly comparison pattern
    for (unsigned int j = 0; j < n && b; j++)
    {
        for (unsigned int i = 0; i < m && b; i++)
        {
            aVal = A[i + (j * m)];
            bVal = B[i + (j * m)];
            if (!approxEqual(aVal, bVal, EPS))
            {
                iFail = i;
                jFail = j;
                b = false;
            }
        }
    }
    return b;
}

template<typename FloatType>
void reportTestSuccess(const char* testName, double GFLOPs, double totalGFLOPs)
{
    printf("%s succeeded: %g GFLOPs, %g GFLOPs acc. for transfers\n", testName, GFLOPs, totalGFLOPs);
}

template<typename FloatType>
void reportTestFailure(const char* testName,
                       const FloatType* orig, const FloatType* cand,
                       unsigned int leadDim,
                       unsigned int iFail, unsigned int jFail)
{
    double oVal = (double)orig[iFail + (jFail * leadDim)];
    double cVal = (double)cand[iFail + (jFail * leadDim)];
    fprintf(stderr, "%s failed: Original[%u, %u] = %.6f != Candidate[%u, %u] = %.6f\n",
            testName, iFail, jFail, oVal, iFail, jFail, cVal);
}

template<typename FloatType>
double getGFLOPs(double time, unsigned int m, unsigned int n, unsigned int k)
{
    double instCount = ((double) m * (double) n * (double) k) / 10e9;
    double timeSeconds = time / 1000;
    return instCount / timeSeconds;
}



/*
  floatTSM2 and doubleTSM2 -- Wrappers around the kernels that select
  the optimal kernel.

  Currently only optimal for Nvidia V100

  Parameter Choice for V100:
  
  t1 := 128
  
  Single Precision: n ~= t2, t3 := 32
  Double Precision: n ~= t2, t3 := 16 if m < 10240, and t3 := 12 otherwise
  
 */

void floatTSM2(const float* devA, const float* devB, float* devC,
               const unsigned int m, const unsigned int n,
               const unsigned int k)
{
    int blocks = (m / FLOAT_T1) + 1;
    blocks = (blocks > 65536) ? 65536 : blocks;

    if (n <= 2)
    {
        floatTSM2Kernel<FLOAT_T1, 2, 32><<<blocks, FLOAT_T1>>>(devA, devB, devC, m, n, k);
    }
    else if (n <= 4)
    {
        floatTSM2Kernel<FLOAT_T1, 4, 32><<<blocks, FLOAT_T1>>>(devA, devB, devC, m, n, k);
    }
    else if (n <= 6)
    {
        floatTSM2Kernel<FLOAT_T1, 6, 32><<<blocks, FLOAT_T1>>>(devA, devB, devC, m, n, k);
    }
    else if (n <= 8)
    {
        floatTSM2Kernel<FLOAT_T1, 8, 32><<<blocks, FLOAT_T1>>>(devA, devB, devC, m, n, k);
    }
    else
    {
        floatTSM2Kernel<FLOAT_T1, 16, 32><<<blocks, FLOAT_T1>>>(devA, devB, devC, m, n, k);
    }
    // Since CUBLAS starts beating TSM2 at 16, there is no need to include another kernel
}

void doubleTSM2(const double* devA, const double* devB, double* devC,
               const unsigned int m, const unsigned int n,
                const unsigned int k)
{
    int blocks = (m / DOUBLE_T1) + 1;
    blocks = (blocks > 65536) ? 65536 : blocks;
    
    if (n <= 2)
    {
        if (m < 20480)
        {
            doubleTSM2Kernel<DOUBLE_T1, 2, 16><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
        else
        {
            doubleTSM2Kernel<DOUBLE_T1, 2, 12><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
    }
    else if (n <= 4)
    {
        if (m < 20480)
        {
            doubleTSM2Kernel<DOUBLE_T1, 4, 16><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
        else
        {
            doubleTSM2Kernel<DOUBLE_T1, 4, 12><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
    }
    else if (n <= 6)
    {
        if (m < 20480)
        {
            doubleTSM2Kernel<DOUBLE_T1, 6, 16><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
        else
        {
            doubleTSM2Kernel<DOUBLE_T1, 6, 12><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
    }
    else if (n <= 8)
    {
        if (m < 20480)
        {
            doubleTSM2Kernel<DOUBLE_T1, 8, 16><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
        else
        {
            doubleTSM2Kernel<DOUBLE_T1, 8, 12><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
    }
    else if (n <= 16)
    {
        if (m < 20480)
        {
            doubleTSM2Kernel<DOUBLE_T1, 16, 16><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
        else
        {
            doubleTSM2Kernel<DOUBLE_T1, 16, 12><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
        }
    }
    else
    {
        doubleTSM2Kernel<DOUBLE_T1, 32, 12><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
    }    
}







/*
  Executes the kernels
 */
template<>
bool runKernels(const float* A, const float* B, float* C,
                const unsigned int m, const unsigned int n,
                const unsigned int k)
{
    // Candidate for C -- Used by GPU kernels
    float* candC;
    // Device memory
    float* devA, * devB, * devC;
    // Events used for timing
    cudaEvent_t start, end, startTotal, endTotal;
    float time, timeTotal;

    printf("Multiplying matrix A[%u, %u] by matrix B[%u, %u]\n\n", m, k, k, n); 

    // Allocates new memory
    candC = (float*)malloc(m * n * sizeof(float));
    if (candC == NULL)
    {
        fprintf(stderr, "Not enough memory\n");
        return false;
    }
    
    cudaErrchk(cudaMalloc((float**)&devA, m * k * sizeof(float)));
    cudaErrchk(cudaMalloc((float**)&devB, k * n * sizeof(float)));
    cudaErrchk(cudaMalloc((float**)&devC, m * n * sizeof(float)));
    
    
    // Inits CUDA events
    cudaErrchk(cudaEventCreate(&start));
    cudaErrchk(cudaEventCreate(&end));
    cudaErrchk(cudaEventCreate(&startTotal));
    cudaErrchk(cudaEventCreate(&endTotal));
    
    // Runs CUBLAS call
    cublasHandle_t handle;
    cublasErrchk(cublasCreate(&handle));
    
    float one = 1;
    float zero = 0;

    cudaErrchk(cudaEventRecord(startTotal));
    
    // Cuda Memory Copy
    cudaErrchk(cudaMemcpy(devA, A, m * k * sizeof(float), cudaMemcpyHostToDevice));
    cudaErrchk(cudaMemcpy(devB, B, k * n * sizeof(float), cudaMemcpyHostToDevice));

    cudaErrchk(cudaEventRecord(start));
    cublasErrchk(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N,
                              m, n, k,
                              &one, devA, CUDA_R_32F, m, devB, CUDA_R_32F, k,
                              &zero, devC, CUDA_R_32F, m, CUDA_R_32F, CUBLAS_GEMM_DEFAULT));
    cudaErrchk(cudaEventRecord(end));
    
    // Copies result back
    cudaErrchk(cudaMemcpy(C, devC, m * n * sizeof(float), cudaMemcpyDeviceToHost));

    cudaErrchk(cudaEventRecord(endTotal));
    cudaErrchk(cudaDeviceSynchronize());
    cudaErrchk(cudaEventElapsedTime(&time, start, end));
    cudaErrchk(cudaEventElapsedTime(&timeTotal, startTotal, endTotal));
    printf("cublas time consume:%f,\t total time: %f\n", time, timeTotal);
    reportTestSuccess<float>("CUBLAS Test", getGFLOPs<float>(time, m, n, k), getGFLOPs<float>(timeTotal, m, n, k)); 

    cublasErrchk(cublasDestroy(handle));
    

    // Runs kernels
    // Failure flag
    bool status;
    // Failure indices
    unsigned int iFail, jFail;

    // Clear result matrix
    cudaErrchk(cudaMemset(devC, 0, m * n * sizeof(float)));
    cudaErrchk(cudaEventRecord(startTotal));
    
    // Cuda Memory Copy
    cudaErrchk(cudaMemcpy(devA, A, m * k * sizeof(float), cudaMemcpyHostToDevice));
    cudaErrchk(cudaMemcpy(devB, B, k * n * sizeof(float), cudaMemcpyHostToDevice));

    int blocks = (k / FLOAT_T1) + 1;
    blocks = (blocks > 65536) ? 65536 : blocks;

    cudaErrchk(cudaEventRecord(start));
    #ifdef SINGLE_PARAM
    floatTSM2Kernel<FLOAT_T1, FLOAT_T2, FLOAT_T3><<<blocks, FLOAT_T1>>>(devA, devB, devC, m, n, k);
    #else
    floatTSM2(devA, devB, devC, m, n, k);
    #endif
    cudaErrchk(cudaGetLastError());
    cudaErrchk(cudaEventRecord(end));
    
    // Copies result back
    cudaErrchk(cudaMemcpy(candC, devC, m * n * sizeof(float), cudaMemcpyDeviceToHost));

    cudaErrchk(cudaEventRecord(endTotal));
    cudaErrchk(cudaDeviceSynchronize());
    cudaErrchk(cudaEventElapsedTime(&time, start, end));
    cudaErrchk(cudaEventElapsedTime(&timeTotal, startTotal, endTotal));
    printf("tsm time consume: %f,\t total time: %f\n", time, timeTotal);
    status = matrixCompare<float>(C, candC, m, n, iFail, jFail);
    if (status)
    {
        reportTestSuccess<float>("TSM2 Kernel Test", 
                                 getGFLOPs<float>(time, m, n, k), 
                                 getGFLOPs<float>(timeTotal, m, n, k)); 
    }
    else
    {
        reportTestFailure<float>("TSM2 Kernel Test", C, candC, m, iFail, jFail);
    }
        
       

    
    cudaErrchk(cudaEventDestroy(start));
    cudaErrchk(cudaEventDestroy(end));
    cudaErrchk(cudaEventDestroy(startTotal));
    cudaErrchk(cudaEventDestroy(endTotal));
    free(candC);
    cudaErrchk(cudaFree(devA));
    cudaErrchk(cudaFree(devB));
    cudaErrchk(cudaFree(devC));
    
    return true;
}




template<>
bool runKernels(const double* A, const double* B, double* C,
                const unsigned int m, const unsigned int n,
                const unsigned int k)
{
    // Candidate for C -- Used by GPU kernels
    double* candC;
    // Device memory
    double* devA, * devB, * devC;
    // Events used for timing
    cudaEvent_t start, end, startTotal, endTotal;
    float time, timeTotal;

    printf("Multiplying matrix A[%u, %u] by matrix B[%u, %u]\n\n", m, k, k, n); 

    // Allocates new memory
    candC = (double*)malloc(m * n * sizeof(double));
    if (candC == NULL)
    {
        fprintf(stderr, "Not enough memory\n");
        return false;
    }
    
    cudaErrchk(cudaMalloc((double**)&devA, m * k * sizeof(double)));
    cudaErrchk(cudaMalloc((double**)&devB, k * n * sizeof(double)));
    cudaErrchk(cudaMalloc((double**)&devC, m * n * sizeof(double)));
    
    
    // Inits CUDA events
    cudaErrchk(cudaEventCreate(&start));
    cudaErrchk(cudaEventCreate(&end));
    cudaErrchk(cudaEventCreate(&startTotal));
    cudaErrchk(cudaEventCreate(&endTotal));
    
    // Runs CUBLAS call
    cublasHandle_t handle;
    cublasErrchk(cublasCreate(&handle));
    
    double one = 1;
    double zero = 0;

    cudaErrchk(cudaEventRecord(startTotal));
    
    // Cuda Memory Copy
    cudaErrchk(cudaMemcpy(devA, A, m * k * sizeof(double), cudaMemcpyHostToDevice));
    cudaErrchk(cudaMemcpy(devB, B, k * n * sizeof(double), cudaMemcpyHostToDevice));

    cudaErrchk(cudaEventRecord(start));
    cublasErrchk(cublasGemmEx(handle, CUBLAS_OP_N, CUBLAS_OP_N,
                              m, n, k,
                              &one, devA, CUDA_R_64F, m, devB, CUDA_R_64F, k,
                              &zero, devC, CUDA_R_64F, m, CUDA_R_64F, CUBLAS_GEMM_DEFAULT));
    cudaErrchk(cudaEventRecord(end));
    
    // Copies result back
    cudaErrchk(cudaMemcpy(C, devC, m * n * sizeof(double), cudaMemcpyDeviceToHost));

    cudaErrchk(cudaEventRecord(endTotal));
    cudaErrchk(cudaDeviceSynchronize());
    cudaErrchk(cudaEventElapsedTime(&time, start, end));
    cudaErrchk(cudaEventElapsedTime(&timeTotal, startTotal, endTotal));
    reportTestSuccess<double>("CUBLAS Test", getGFLOPs<double>(time, m, n, k), getGFLOPs<double>(timeTotal, m, n, k)); 

    cublasErrchk(cublasDestroy(handle));
    

    
    
    // Runs kernel
    // Failure flag
    bool status;
    // Failure indices
    unsigned int iFail, jFail;


    // If a TSM

    // Clear result matrix
    cudaErrchk(cudaMemset(devC, 0, m * n * sizeof(double)));
    cudaErrchk(cudaEventRecord(startTotal));
    
    // Cuda Memory Copy
    cudaErrchk(cudaMemcpy(devA, A, m * k * sizeof(double), cudaMemcpyHostToDevice));
    cudaErrchk(cudaMemcpy(devB, B, k * n * sizeof(double), cudaMemcpyHostToDevice));

    int blocks = (k / DOUBLE_T1) + 1;
    blocks = (blocks > 65536) ? 65536 : blocks;

    cudaErrchk(cudaEventRecord(start));
    #ifdef SINGLE_PARAM
    doubleTSM2Kernel<DOUBLE_T1, DOUBLE_T2, DOUBLE_T3><<<blocks, DOUBLE_T1>>>(devA, devB, devC, m, n, k);
    #else
    doubleTSM2(devA, devB, devC, m, n, k);
    #endif
    cudaErrchk(cudaGetLastError());
    cudaErrchk(cudaEventRecord(end));
    
    // Copies result back
    cudaErrchk(cudaMemcpy(candC, devC, m * n * sizeof(double), cudaMemcpyDeviceToHost));

    cudaErrchk(cudaEventRecord(endTotal));
    cudaErrchk(cudaDeviceSynchronize());
    cudaErrchk(cudaEventElapsedTime(&time, start, end));
    cudaErrchk(cudaEventElapsedTime(&timeTotal, startTotal, endTotal));
    status = matrixCompare<double>(C, candC, m, n, iFail, jFail);
    if (status)
    {
        reportTestSuccess<double>("TSM2 Kernel Test", 
                                  getGFLOPs<double>(time, m, n, k), 
                                  getGFLOPs<double>(timeTotal, m, n, k)); 
    }
    else
    {
        reportTestFailure<double>("TSM2 Kernel Test", C, candC, m, iFail, jFail);
    }



    cudaErrchk(cudaEventDestroy(start));
    cudaErrchk(cudaEventDestroy(end));
    cudaErrchk(cudaEventDestroy(startTotal));
    cudaErrchk(cudaEventDestroy(endTotal));
    free(candC);
    cudaErrchk(cudaFree(devA));
    cudaErrchk(cudaFree(devB));
    cudaErrchk(cudaFree(devC));
    
    return true;
}