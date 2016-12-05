/*******************************************************
 * Copyright (c) 2014, ArrayFire
 * All rights reserved.
 *
 * This file is distributed under 3-clause BSD license.
 * The complete license agreement can be obtained at:
 * http://arrayfire.com/licenses/BSD-3-Clause
 ********************************************************/

#include <sparse.hpp>
#include <cusparseManager.hpp>
#include <kernel/sparse_arith.hpp>

#include <stdexcept>
#include <string>

#include <arith.hpp>
#include <cast.hpp>
#include <complex.hpp>
#include <copy.hpp>
#include <err_common.hpp>
#include <lookup.hpp>
#include <math.hpp>
#include <platform.hpp>
#include <where.hpp>

namespace cuda
{

using cusparse::getHandle;
using namespace common;
using namespace std;

template<typename T>
T getInf()
{
    return scalar<T>(std::numeric_limits<T>::infinity());
}

template<>
cfloat getInf()
{
    return scalar<cfloat, float>(NAN, NAN); // Matches behavior of complex division by 0 in CUDA
}

template<>
cdouble getInf()
{
    return scalar<cdouble, double>(NAN, NAN); // Matches behavior of complex division by 0 in CUDA
}

template<typename T, af_op_t op>
Array<T> arithOp(const SparseArray<T> &lhs, const Array<T> &rhs, const bool reverse)
{
    lhs.eval();
    rhs.eval();

    Array<T> out = createEmptyArray<T>(dim4(0));
    Array<T> zero = createValueArray<T>(rhs.dims(), scalar<T>(0));
    switch(op) {
        case af_add_t: out = copyArray<T>(rhs); break;
        case af_sub_t: out = reverse ? copyArray<T>(rhs) : arithOp<T, af_sub_t>(zero, rhs, rhs.dims()); break;
        case af_mul_t: out = zero; break;
        case af_div_t: out = reverse ? createValueArray(rhs.dims(), getInf<T>()) : zero; break;
        default      : out = copyArray<T>(rhs);
    }
    out.eval();
    switch(lhs.getStorage()) {
        case AF_STORAGE_CSR:
            kernel::sparseArithOpCSR<T, op>(out, lhs.getValues(), lhs.getRowIdx(), lhs.getColIdx(),
                                            rhs, reverse);
            break;
        case AF_STORAGE_COO:
            kernel::sparseArithOpCOO<T, op>(out, lhs.getValues(), lhs.getRowIdx(), lhs.getColIdx(),
                                            rhs, reverse);
            break;
        default:
            AF_ERROR("Sparse Arithmetic only supported for CSR or COO", AF_ERR_NOT_SUPPORTED);
    }

    return out;
}

#define INSTANTIATE(T)                                                                          \
    template Array<T> arithOp<T, af_add_t>(const SparseArray<T> &lhs, const Array<T> &rhs,      \
                                           const bool reverse);                                 \
    template Array<T> arithOp<T, af_sub_t>(const SparseArray<T> &lhs, const Array<T> &rhs,      \
                                           const bool reverse);                                 \
    template Array<T> arithOp<T, af_mul_t>(const SparseArray<T> &lhs, const Array<T> &rhs,      \
                                           const bool reverse);                                 \
    template Array<T> arithOp<T, af_div_t>(const SparseArray<T> &lhs, const Array<T> &rhs,      \
                                           const bool reverse);                                 \

INSTANTIATE(float  )
INSTANTIATE(double )
INSTANTIATE(cfloat )
INSTANTIATE(cdouble)

}
