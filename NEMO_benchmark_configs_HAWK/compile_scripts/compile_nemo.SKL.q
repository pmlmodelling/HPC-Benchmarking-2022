#!/bin/bash
#SBATCH -J NEMO
#SBATCH -o NEMO.compile.SKL.o.%J
#SBATCH -e NEMO.compile.SKL.e.%J
#SBATCH --ntasks=40
#SBATCH --ntasks-per-node=40
#SBATCH -p xdev
#SBATCH --time=0:30:00
#SBATCH --exclusive
#
#########################################
#Load netcdf, hdf5 and cmake modules and set environment variables
#########################################

module purge
module load compiler/intel/2020/2   
module load mpi/intel/2020/2
module load cmake
#
module load netcdf/4.6.1
module load hdf5/1.10.2

# export WORK=/path/to/working/dir
export WORK=/scratch/$USER/NEMO-benchmark-cfg
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
ARCH=$XIOS_DIR/arch/arch-X64_HAWKSKL
ARCH=X64_HAWKSKL

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
ARCH=X86_HAWKSKL_FABM

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
