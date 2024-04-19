#!/bin/bash

#SBATCH --job-name=sowfa24x
#SBATCH --output=log.sowfa24x
#SBATCH --nodes=1
#SBATCH --ntasks=24
#SBATCH --mem=128G
#SBATCH --partition=k2-medpri,medpri
#SBATCH --time=1-00:00:00


############################### GET SOURCE CODE ################################

export FOAM_INST_DIR=$HOME/OpenFOAM

mkdir $FOAM_INST_DIR

cd $FOAM_INST_DIR
git clone https://github.com/OpenFOAM/ThirdParty-5.x.git
git clone https://github.com/OpenFOAM/ThirdParty-2.4.x.git
git clone https://github.com/OpenFOAM/OpenFOAM-2.4.x.git
git clone https://github.com/NotDrJeff/SOWFA-2.4.x.git
cd - > /dev/null

for dir in ThirdParty-5.x ThirdParty-2.4.x OpenFOAM-2.4.x SOWFA-2.4.x; do
    cd $FOAM_INST_DIR/$dir
    git clean -df
    cd - > /dev/null
done

cd $FOAM_INST_DIR/ThirdParty-2.4.x
if ! [ -f "CGAL-4.6.3.tar.gz" ]; then
    wget -nv 'https://github.com/CGAL/cgal/archive/refs/tags/releases/CGAL-4.6.3.tar.gz'
    echo "Extracting archive..."
    tar -xf CGAL-4.6.3.tar.gz
    mv cgal-releases-CGAL-4.6.3 CGAL-4.6
fi
if ! [ -a "scotch_6.0.3" ]; then
    ln -s ../ThirdParty-5.x/scotch_6.0.3 $FOAM_INST_DIR/ThirdParty-2.4.x/scotch_6.0.3
fi
cd - > /dev/null

############################## ENVIRONMENT SETUP ###############################

module purge
module load mpi/openmpi/1.10.1/gcc-4.8.5
module load apps/cmake/3.5.2/gcc-4.8.5

if [ -z "$OPENFOAM_VERSION" ]; then
    echo "Nothing to unset..."
else
    echo "Unsetting OpenFOAM environment variables..."
    . $FOAM_INST_DIR/OpenFOAM-$OPENFOAM_VERSION/etc/config/unset.sh 2>&1 \
                                                                    > /dev/null
    export FOAM_INST_DIR=$HOME/OpenFOAM
fi

export OPENFOAM_VERSION=2.4.x
export OPENFOAM_NAME=OpenFOAM-$OPENFOAM_VERSION
foamDotFile=$FOAM_INST_DIR/$OPENFOAM_NAME/etc/bashrc

if [ -f $foamDotFile ]; then
    echo "Sourcing $foamDotFile..."
    source $foamDotFile
fi

export WM_NCOMPPROCS=24
export WM_COLOURS="white blue green cyan red magenta yellow"
export SOWFA_DIR=$FOAM_INST_DIR/SOWFA
export LD_LIBRARY_PATH=$SOWFA_DIR/lib/$WM_OPTIONS:$LD_LIBRARY_PATH
export PATH=$SOWFA_DIR/applications/bin/$WM_OPTIONS:$PATH

################################# COMPILATION ##################################

echo "Cleaning ThirdParty Directory"
$WM_THIRD_PARTY_DIR/Allclean > $WM_THIRD_PARTY_DIR/log.Allclean.1 2>&1
echo "Compile ThirdParty Directorty."
$WM_THIRD_PARTY_DIR/Allwmake > $WM_THIRD_PARTY_DIR/log.Allwmake.1 2>&1

echo "Cleaning OpenFOAM Directory"
$WM_PROJECT_DIR/Allclean > $WM_PROJECT_DIR/log.Allclean.1 2>&1
echo "Compile OpenFOAM Directorty."
$WM_PROJECT_DIR/Allwmake > $WM_PROJECT_DIR/log.Allwmake.1 2>&1

echo "Peforming Second Sweep"
$WM_PROJECT_DIR/Allwmake > $WM_PROJECT_DIR/log.Allwmake.2 2>&1

cd $SOWFA_DIR
echo "Compile SOWFA Directorty."
$SOWFA_DIR/Allwmake > $SOWFA_DIR/log.Allwmake.1 2>&1
echo "Performing Second Sweep"
$SOWFA_DIR/Allwmake > $SOWFA_DIR/log.Allwmake.2 2>&1
cd - > /dev/null
