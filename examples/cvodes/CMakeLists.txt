# ---------------------------------------------------------------
# Programmer(s): David J. Gardner and Slaven Peles @ LLNL
# ---------------------------------------------------------------
# SUNDIALS Copyright Start
# Copyright (c) 2002-2019, Lawrence Livermore National Security
# and Southern Methodist University.
# All rights reserved.
#
# See the top-level LICENSE and NOTICE files for details.
#
# SPDX-License-Identifier: BSD-3-Clause
# SUNDIALS Copyright End
# ---------------------------------------------------------------
# examples/cvodes level CMakeLists.txt for SUNDIALS
# ---------------------------------------------------------------

# C examples
if(EXAMPLES_ENABLE_C)
  add_subdirectory(serial)
  if(MPI_ENABLE AND MPI_C_FOUND)
    add_subdirectory(parallel)
  endif()
  if(OPENMP_ENABLE AND OPENMP_FOUND)
    add_subdirectory(C_openmp)
  endif()
endif()

if(F2003_INTERFACE_ENABLE AND EXAMPLES_ENABLE_F2003 AND F2003_FOUND)
  add_subdirectory(F2003_serial)
endif()