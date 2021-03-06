/*
 * Copyright (c) 2016-2018 ARM Limited.
 *
 * SPDX-License-Identifier: MIT
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
#include "helpers.h"

#ifdef SATURATE
#define ADD(x, y) add_sat((x), (y))
#define SUB(x, y) sub_sat((x), (y))
#else /* SATURATE */
#define ADD(x, y) (x) + (y)
#define SUB(x, y) (x) - (y)
#endif /* SATURATE */

#define CONVERT_RTE(x, type) (convert_##type##_rte((x)))
#define CONVERT_DOWN(x, type) CONVERT_RTE(x, type)

#if defined(OFFSET_IN1) && defined(OFFSET_IN2) && defined(OFFSET_OUT) && defined(SCALE_IN1) && defined(SCALE_IN2) && defined(SCALE_OUT)

#if defined(VEC_SIZE)

#define VEC_FLOAT VEC_DATA_TYPE(float, VEC_SIZE)
#define VEC_INT VEC_DATA_TYPE(int, VEC_SIZE)
#define VEC_UCHAR VEC_DATA_TYPE(uchar, VEC_SIZE)

/** This function adds two tensors.
 *
 * @note The quantization offset of the first operand must be passed at compile time using -DOFFSET_IN1, i.e. -DOFFSET_IN1=10
 * @note The quantization offset of the second operand must be passed at compile time using -DOFFSET_IN2, i.e. -DOFFSET_IN2=10
 * @note The quantization offset of the output must be passed at compile time using -DOFFSET_OUT, i.e. -DOFFSET_OUT=10
 * @note The quantization scale of the first operand must be passed at compile time using -DSCALE_IN1, i.e. -DSCALE_IN1=10
 * @note The quantization scale of the second operand must be passed at compile time using -DSCALE_IN2, i.e. -DSCALE_IN2=10
 * @note The quantization scale of the output must be passed at compile time using -DSCALE_OUT, i.e. -DSCALE_OUT=10
 * @note To perform saturating operation -DSATURATE has to be passed to the compiler otherwise wrapping policy will be used.
 * @note Vector size should be given as a preprocessor argument using -DVEC_SIZE=size. e.g. -DVEC_SIZE=16
 *
 * @param[in]  in1_ptr                           Pointer to the source tensor. Supported data types: QASYMM8
 * @param[in]  in1_stride_x                      Stride of the source tensor in X dimension (in bytes)
 * @param[in]  in1_step_x                        in1_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  in1_stride_y                      Stride of the source tensor in Y dimension (in bytes)
 * @param[in]  in1_step_y                        in1_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  in1_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  in1_step_z                        in1_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  in1_offset_first_element_in_bytes The offset of the first element in the source tensor
 * @param[in]  in2_ptr                           Pointer to the source tensor. Supported data types: same as @p in1_ptr
 * @param[in]  in2_stride_x                      Stride of the source tensor in X dimension (in bytes)
 * @param[in]  in2_step_x                        in2_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  in2_stride_y                      Stride of the source tensor in Y dimension (in bytes)
 * @param[in]  in2_step_y                        in2_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  in2_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  in2_step_z                        in2_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  in2_offset_first_element_in_bytes The offset of the first element in the source tensor
 * @param[out] out_ptr                           Pointer to the destination tensor. Supported data types: same as @p in1_ptr
 * @param[in]  out_stride_x                      Stride of the destination tensor in X dimension (in bytes)
 * @param[in]  out_step_x                        out_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  out_stride_y                      Stride of the destination tensor in Y dimension (in bytes)
 * @param[in]  out_step_y                        out_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  out_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  out_step_z                        out_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  out_offset_first_element_in_bytes The offset of the first element in the destination tensor
 */
__kernel void arithmetic_add_quantized(
    TENSOR3D_DECLARATION(in1),
    TENSOR3D_DECLARATION(in2),
    TENSOR3D_DECLARATION(out))
{
    // Get pixels pointer
    Tensor3D in1 = CONVERT_TO_TENSOR3D_STRUCT(in1);
    Tensor3D in2 = CONVERT_TO_TENSOR3D_STRUCT(in2);
    Tensor3D out = CONVERT_TO_TENSOR3D_STRUCT(out);

    VEC_INT in_a = CONVERT(VLOAD(VEC_SIZE)(0, (__global uchar *)in1.ptr), VEC_INT);
    VEC_INT in_b = CONVERT(VLOAD(VEC_SIZE)(0, (__global uchar *)in2.ptr), VEC_INT);

    in_a = SUB(in_a, (VEC_INT)((int)OFFSET_IN1));
    in_b = SUB(in_b, (VEC_INT)((int)OFFSET_IN2));

    const VEC_FLOAT in1f32 = CONVERT(in_a, VEC_FLOAT) * (VEC_FLOAT)((float)SCALE_IN1);
    const VEC_FLOAT in2f32 = CONVERT(in_b, VEC_FLOAT) * (VEC_FLOAT)((float)SCALE_IN2);

    const VEC_FLOAT qresf32 = (in1f32 + in2f32) / ((VEC_FLOAT)(float)SCALE_OUT) + ((VEC_FLOAT)((float)OFFSET_OUT));
    const VEC_UCHAR res     = CONVERT_SAT(CONVERT_DOWN(qresf32, VEC_INT), VEC_UCHAR);

    // Store result
    VSTORE(VEC_SIZE)
    (res, 0, (__global uchar *)out.ptr);
}
#endif /* defined(VEC_SIZE) */

/** This function subtracts two tensors.
 *
 * @note The quantization offset of the first operand must be passed at compile time using -DOFFSET_IN1, i.e. -DOFFSET_IN1=10
 * @note The quantization offset of the second operand must be passed at compile time using -DOFFSET_IN2, i.e. -DOFFSET_IN2=10
 * @note The quantization offset of the output must be passed at compile time using -DOFFSET_OUT, i.e. -DOFFSET_OUT=10
 * @note The quantization scale of the first operand must be passed at compile time using -DSCALE_IN1, i.e. -DSCALE_IN1=10
 * @note The quantization scale of the second operand must be passed at compile time using -DSCALE_IN2, i.e. -DSCALE_IN2=10
 * @note The quantization scale of the output must be passed at compile time using -DSCALE_OUT, i.e. -DSCALE_OUT=10
 * @note To perform saturating operation -DSATURATE has to be passed to the compiler otherwise wrapping policy will be used.
 *
 * @param[in]  in1_ptr                           Pointer to the source tensor. Supported data types: QASYMM8
 * @param[in]  in1_stride_x                      Stride of the source tensor in X dimension (in bytes)
 * @param[in]  in1_step_x                        in1_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  in1_stride_y                      Stride of the source tensor in Y dimension (in bytes)
 * @param[in]  in1_step_y                        in1_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  in1_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  in1_step_z                        in1_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  in1_offset_first_element_in_bytes The offset of the first element in the source tensor
 * @param[in]  in2_ptr                           Pointer to the source tensor. Supported data types: same as @p in1_ptr
 * @param[in]  in2_stride_x                      Stride of the source tensor in X dimension (in bytes)
 * @param[in]  in2_step_x                        in2_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  in2_stride_y                      Stride of the source tensor in Y dimension (in bytes)
 * @param[in]  in2_step_y                        in2_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  in2_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  in2_step_z                        in2_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  in2_offset_first_element_in_bytes The offset of the first element in the source tensor
 * @param[out] out_ptr                           Pointer to the destination tensor. Supported data types: same as @p in1_ptr
 * @param[in]  out_stride_x                      Stride of the destination tensor in X dimension (in bytes)
 * @param[in]  out_step_x                        out_stride_x * number of elements along X processed per workitem(in bytes)
 * @param[in]  out_stride_y                      Stride of the destination tensor in Y dimension (in bytes)
 * @param[in]  out_step_y                        out_stride_y * number of elements along Y processed per workitem(in bytes)
 * @param[in]  out_stride_z                      Stride of the source tensor in Z dimension (in bytes)
 * @param[in]  out_step_z                        out_stride_z * number of elements along Z processed per workitem(in bytes)
 * @param[in]  out_offset_first_element_in_bytes The offset of the first element in the destination tensor
 */
__kernel void arithmetic_sub_quantized(
    TENSOR3D_DECLARATION(in1),
    TENSOR3D_DECLARATION(in2),
    TENSOR3D_DECLARATION(out))
{
    // Get pixels pointer
    Tensor3D in1 = CONVERT_TO_TENSOR3D_STRUCT(in1);
    Tensor3D in2 = CONVERT_TO_TENSOR3D_STRUCT(in2);
    Tensor3D out = CONVERT_TO_TENSOR3D_STRUCT(out);

    int16 in_a = CONVERT(vload16(0, (__global uchar *)in1.ptr), int16);
    int16 in_b = CONVERT(vload16(0, (__global uchar *)in2.ptr), int16);

    in_a = SUB(in_a, (int16)((int)OFFSET_IN1));
    in_b = SUB(in_b, (int16)((int)OFFSET_IN2));

    const float16 in1f32  = convert_float16(in_a) * (float16)((float)SCALE_IN1);
    const float16 in2f32  = convert_float16(in_b) * (float16)((float)SCALE_IN2);
    const float16 qresf32 = (in1f32 - in2f32) / ((float16)(float)SCALE_OUT) + ((float16)((float16)OFFSET_OUT));
    const uchar16 res     = convert_uchar16_sat(convert_int16_rte(qresf32));

    // Store result
    vstore16(res, 0, (__global uchar *)out.ptr);
}
#endif /* defined(OFFSET_IN1) && defined(OFFSET_IN2) && defined(OFFSET_OUT) && defined(SCALE_IN1) && defined(SCALE_IN2) && defined(SCALE_OUT) */
