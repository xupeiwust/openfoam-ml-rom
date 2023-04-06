#/bin/bash
#
# Copyright (c) 2022 Carlos Peña-Monferrer. All rights reserved.
# This work is licensed under the terms of the GNU LGPL v3.0 license.
# For a copy, see <https://opensource.org/licenses/LGPL-3.0>.
#

#run_case() {
#  PARENT_DIR="runs/$k"
#  CONSTANT_DIR="$PARENT_DIR/constant"

#  mkdir -p "$CONSTANT_DIR" "$PARENT_DIR/system" "$PARENT_DIR/0.orig"

#  cp -r inputs "$PARENT_DIR/"
#  cp -r system 0.orig Allrun.case "$PARENT_DIR/"
#  cp constant/transportProperties "$CONSTANT_DIR"

#  for file in transportProperties turbulenceProperties triSurface; do
#    cd "$CONSTANT_DIR"
#    ln -s "../../../constant/$file" "$file"
#  done

#  fileName=$(basename "${STL_FILES[$k]}")
#  filePath="${STL_FILES[$k]}"

#  eval foamDictionary inputs -entry stlNameFull \
#    -set \'\"${filePath}\"\' -disableFunctionEntries
#  foamDictionary inputs -entry stlName -set "$fileName" -disableFunctionEntries
#  foamDictionary inputs -entry Ux -set "${U_PARAMS[$k]}" -disableFunctionEntries

#  shape=$(foamDictionary -entry stlName inputs -value)
#  printf '%s\n' "${shape%.*}" >shape
#
#  cd "$PARENT_DIR"
#  ./Allrun.case

#  OUTPUT_DIRS=($(foamListTimes -time '.*' -case .))
#  OUTPUT_DIR="${OUTPUT_DIRS[-1]}"
#
#  cd ../sequencedVTU
#  ln -s "$PARENT_DIR/base/0" "$OUTPUT_DIR"
#  cd ../sequencedSTL
#  ln -s "$CONSTANT_DIR/triSurface/$fileName" "${OUTPUT_DIR}.stl"
#}

run_case () {
  CASE_DIR="runs/$k"

  mkdir -p ${CASE_DIR}/constant
  cp -r system 0.orig Allrun.case inputs ${CASE_DIR}
  cp constant/transportProperties ${CASE_DIR}/constant/

  cd ${CASE_DIR}/constant
  ln -s ../../../constant/transportProperties transportProperties
  ln -s ../../../constant/turbulenceProperties turbulenceProperties
  ln -s ../../../constant/triSurface triSurface
  cd ..

  fileName=$(basename ${STL_FILES[$k]})
  filePath=${STL_FILES[$k]}

  eval foamDictionary inputs -entry stlNameFull -set \'\"${filePath}\"\' -disableFunctionEntries 
  foamDictionary inputs -entry stlName -set $fileName -disableFunctionEntries
  foamDictionary inputs -entry Ux -set ${U_PARAMS[$k]} -disableFunctionEntries

  shape=$(foamDictionary -entry stlName inputs -value)
  echo ${shape%.*} > shape
  ./Allrun.case

  OUTPUT_DIR=$(($k + 1))
  cd ../../sequencedVTU
  ln -s ../${CASE_DIR}/base/0 ${OUTPUT_DIR}
  cd ../sequencedSTL
  ln -s ../constant/triSurface/$fileName ${OUTPUT_DIR}.stl
}

#  - Configuration
CORES=$1
LANG=en_US
NAME=flowAroundObstacles

OFFLINE_PATH=sequencedVTU
STL_PATH=sequencedSTL

#  - Parameter ranges
U_MIN=0.075
U_MAX=0.075
U_STEP=0.075

if [ ! -d ${OFFLINE_PATH} ];then
  mkdir -p ${OFFLINE_PATH}
  (cd ${OFFLINE_PATH} &&
   ln -s ../constant constant &&
   ln -s ../system system)
fi

if [ ! -d ${STL_PATH} ];then
  mkdir -p ${STL_PATH}
fi

N_PARAMS=0
for stl in constant/triSurface/*.stl; do
  for U in $(seq $U_MIN $U_STEP $U_MAX); do
    let "N_PARAMS=N_PARAMS+1"
    U_PARAMS=( "${U_PARAMS[@]}" "$U" )
    STL_FILES=( "${STL_FILES[@]}" "$stl" )
  done
done

k=0
while [ $k -lt ${N_PARAMS} ]
do
  for i in `seq ${CORES}`
  do
    if [ $k -lt ${N_PARAMS} ]; then
      (run_case $k ${U_PARAMS[$k]} ${STL_FILES[$k]}) &
      let "k=k+1"
    fi
  done
  wait
done
