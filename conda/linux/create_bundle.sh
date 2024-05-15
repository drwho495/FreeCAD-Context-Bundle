#!/bin/bash

export MAMBA_NO_BANNER=1
if [[ -z "$ARCH" ]]; then
  # Get the architecture of the system
  export ARCH=$(uname -m)
fi
conda_env="AppDir/usr"
echo -e "\nCreate the environment"

packages="occt vtk xerces-c libspnav pivy ros-humble-libyaml-vendor pyside2 r-libcoin python=3.11 blas=*=openblas numpy \
          l-nafaryus::netgen=6.2.2105.152 matplotlib-base scipy sympy pandas six pyyaml pycollada lxml \
          xlutils olefile requests blinker opencv nine docutils \
          opencamlib calculix ifcopenshell lark appimage-updater-bridge"
#if [[ "$ARCH" = "x86_64" ]]; then
#  packages=${packages}" ifcopenshell appimage-updater-bridge"
#fi

sudo wget https://github.com/drwho495/freecad-context-feedstock/releases/download/conda-release/linux-conda-release.zip
sudo mkdir ./conda-packages
sudo unzip ./linux-conda-release.zip -d ./conda-packages
sudo chmod 777 ./conda-packages/*

mamba create -p ${conda_env} ${packages} \
  --copy -c freecad/label/dev -c l-nafaryus -c robostack-staging -c conda-forge -y

#installing freecad
echo "Installing FreeCAD Context .conda..."

mamba install -p ${conda_env} ./conda-packages/* --copy -c freecad/label/dev -y


mamba run -p ${conda_env} python ../scripts/get_freecad_version.py
read -r version_name < bundle_name.txt

echo -e "\################"
echo -e "version_name:  ${version_name}"
echo -e "################"

echo -e "\nInstall freecad.appimage_updater"
mamba run -p ${conda_env} pip install https://github.com/looooo/freecad.appimage_updater/archive/master.zip

echo -e "\nUninstall some packages not needed"
conda uninstall -p ${conda_env} libclang --force -y

mamba list -p ${conda_env} > AppDir/packages.txt
sed -i "1s/.*/\nLIST OF PACKAGES:/" AppDir/packages.txt

echo -e "\nDelete unnecessary stuff"
rm -rf ${conda_env}/include
find ${conda_env} -name \*.a -delete
mv ${conda_env}/bin ${conda_env}/bin_tmp
mkdir ${conda_env}/bin
cp ${conda_env}/bin_tmp/freecad ${conda_env}/bin/
cp ${conda_env}/bin_tmp/freecadcmd ${conda_env}/bin/
cp ${conda_env}/bin_tmp/ccx ${conda_env}/bin/
cp ${conda_env}/bin_tmp/python ${conda_env}/bin/
cp ${conda_env}/bin_tmp/pip ${conda_env}/bin/
cp ${conda_env}/bin_tmp/pyside2-rcc ${conda_env}/bin/
cp ${conda_env}/bin_tmp/gmsh ${conda_env}/bin/
cp ${conda_env}/bin_tmp/dot ${conda_env}/bin/
sed -i '1s|.*|#!/usr/bin/env python|' ${conda_env}/bin/pip
rm -rf ${conda_env}/bin_tmp

echo -e "\nCopy qt.conf"
cp qt.conf ${conda_env}/bin/
cp qt.conf ${conda_env}/libexec/

echo -e "\nCopying Icon and Desktop file"
cp ${conda_env}/share/applications/org.freecad.FreeCAD.desktop AppDir/
sed -i 's/Exec=FreeCAD/Exec=AppRun/g' AppDir/org.freecad.FreeCAD.desktop
if [ "$DEPLOY_RELEASE" = "weekly-builds" ]; then
  cp freecad_weekly.svg ${conda_env}/share/icons/hicolor/scalable/apps/org.freecad.FreeCAD.svg
  sed -i 's/=FreeCAD/=FreeCAD Weekly/g' AppDir/org.freecad.FreeCAD.desktop
fi
cp ${conda_env}/share/icons/hicolor/scalable/apps/org.freecad.FreeCAD.svg AppDir/


# Remove __pycache__ folders and .pyc files
find . -path "*/__pycache__/*" -delete
find . -name "*.pyc" -type f -delete

# reduce size
rm -rf ${conda_env}/conda-meta/
rm -rf ${conda_env}/doc/global/
rm -rf ${conda_env}/share/gtk-doc/
rm -rf ${conda_env}/lib/cmake/

find . -name "*.h" -type f -delete
find . -name "*.cmake" -type f -delete

echo -e "\nAdd libnsl (Fedora 28 and up)"
cp ../../libc6/lib/$ARCH-linux-gnu/libnsl* ${conda_env}/lib/

if [ "$DEPLOY_RELEASE" = "weekly-builds" ]; then
  export tag="weekly-builds"
else
  export tag="latest"
fi

echo -e "\nCreate the appimage"
if [ "$ARCH" = "aarch64" ]; then
  export ARCH=arm_aarch64
fi
chmod a+x ./AppDir/AppRun
../../appimagetool-$(uname -m).AppImage \
  -u "gh-releases-zsync|FreeCAD|FreeCAD-Bundle|$tag|FreeCAD*$ARCH*.AppImage.zsync" \
  AppDir  ${version_name}.AppImage

echo -e "\nCreate hash"
shasum -a 256 ${version_name}.AppImage > ${version_name}.AppImage-SHA256.txt
