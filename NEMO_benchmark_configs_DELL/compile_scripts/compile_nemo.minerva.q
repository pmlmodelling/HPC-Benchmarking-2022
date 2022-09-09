#!/bin/bash
#SBATCH -J NEMO
#SBATCH -o NEMO.compile.7702.o.%J
#SBATCH -e NEMO.compile.7702.e.%J
#SBATCH --ntasks=128
#SBATCH --ntasks-per-node=128
#SBATCH -p 7702
#SBATCH --time=0:30:00
#SBATCH --exclusive
#
#########################################
#Load netcdf, hdf5 and cmake modules and set environment variables
#########################################

module purge
module load shared
module load core
module load hpc
#
#module load intel/mpi/$compile
module load intel/oneAPI/2022.2.0
# compile=19.1.3.304
# module load intel/compiler/$compile
module load icc/2022.1.0
module load mpi/2021.6.0
#
module load cmake
#
# module load netcdf/4.6.1
module load netcdf/intel21/impi/4.9.0
module load hdf5/intel21/impi/1.13.1

# export WORK=/path/to/working/dir
export WORK=/work/$USER/NEMO-benchmark-cfg
export CODE_DIR=$WORK/code

#################################################
# Script to compile XIOS2.5
#################################################

# set compile architecture and export compilers
# export CC=cc export CXX=CC export FC=ftn export F77=ftn export F90=ftn
export CC=mpiicc export CXX=mpiicc export FC=mpiifort export F77=mpiifort export F90=mpiifort

#-------------------------------------------------------
# Build xios
XIOS_DIR=$CODE_DIR/xios
XIOS_BUILD=$CODE_DIR/xios-build
# ARCH=X86_ARCHER2-Cray
ARCH=$XIOS_DIR/arch/arch-X64_MINERVA
ARCH=X64_MINERVA

cd $XIOS_DIR 

$XIOS_DIR/make_xios --prod --arch $ARCH --netcdf_lib netcdf4_par --job 16 --full

rsync -a $XIOS_DIR/bin $XIOS_DIR/inc $XIOS_DIR/lib $XIOS_BUILD

cd $WORK
# -------------------------------------------------------

################################################
# Build FABM
###############################################

# Set compiler
FABM_FORTRAN_COMPILER=mpiifort

#------------------------------------------------------
ERSEM_DIR=$CODE_DIR/ersem
FABM_DIR=$CODE_DIR/fabm
FABM_BUILD=$CODE_DIR/fabm-build

rm -rf $FABM_BUILD
mkdir $FABM_BUILD

cd $FABM_BUILD
cmake $FABM_DIR/src -DFABM_HOST=nemo -DFABM_ERSEM_BASE=$ERSEM_DIR -DFABM_EMBED_VERSION=ON -DCMAKE_INSTALL_PREFIX=$FABM_BUILD -DCMAKE_Fortran_COMPILER=$FABM_FORTRAN_COMPILER
make
make install -j4

cd $WORK
# ----------------------------------------------------------------------------------------

#############################################
# Build NEMO
#############################################

#Define architecture
#ARCH=X86_ARCHER2-Cray_FABM
#ARCH=X86_HAWKSKL_FABM
#ARCH=X86_ZENITHCSL_FABM
ARCH=X86_MINERVA_FABM

#---------------------------------------------------------------
#Build
export FABM_HOME=$CODE_DIR/fabm-build
export XIOS_HOME=$CODE_DIR/xios-build
NEMO_DIR=$CODE_DIR/nemo
cd $NEMO_DIR

CFG=AMM7_FABM_BENCHMARK
REF=AMM7_FABM
printf 'y\nn\nn\ny\nn\nn\nn\nn\n' |./makenemo -n $CFG -r $REF -m $ARCH -j 0
./makenemo -n $CFG -r $REF -m $ARCH -j 4 clean
./makenemo -n $CFG -r $REF -m $ARCH -j 4 

cd $WORK
#---------------------------------------------------------------
