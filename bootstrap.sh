#!/usr/bin/env bash

echo "************** Updating System and Installing Requirements **************"
echo "************** Starting with Project Install **************"

PANUSER=panoptes
PANDIR=/var/panoptes
# PANHOME=/home/${PANUSER}
#ANACONDADIR=/opt/anaconda3
PANHOME=$HOME
ANACONDADIR=$HOME/anaconda3

function add_to_bashrc() {
    echo "Adding environmental variable: $1=$2";

    # Also add to current environment
    export $1=$2

    cat <<END >> ${PANHOME}/.bashrc
export $1=$2
END
source ${PANHOME}/.bashrc

    if [ -d /home/vagrant ]; then
        cat <<END >> /home/vagrant/.bashrc
export $1=$2
END
        source /home/vagrant/.bashrc
    fi

}


echo "************** Setting up panoptes user **************"
if ! id -u $PANUSER >/dev/null 2>&1; then
    sudo adduser --system --group --disabled-login --gecos "PANOPTES User" $PANUSER
    sudo adduser $USER $PANUSER # Current user to panoptes group
fi

sudo adduser $PANUSER dialout

if [ ! -d "$PANDIR" ]; then
    echo "************** Creating directories **************"
    if [ -d /vagrant ]; then
        ln -s /vagrant $PANDIR
    fi

    for dir in data images webcams logs
    do
        sudo mkdir -p $PANDIR/$dir
    done

    echo "************** Setting up directory permissions **************"
    sudo chown -R $PANUSER:$PANUSER $PANDIR

    add_to_bashrc 'PANDIR' $PANDIR
    add_to_bashrc 'PANUSER' $PANUSER
fi

# Install additional useful software
echo "************** Installing some required software **************"
sudo apt-get install -y \
    aptitude \
    build-essential \
    fftw3 \
    fftw3-dev \
    fswebcam \
    git \
    htop \
    libatlas-base-dev \
    libatlas-dev \
    libplplot-dev \
    mongodb \
    openssh-server \
    sextractor \
    >>$PANDIR/bootstrap.log 2>&1;

# Clone repos
for repo in POCS PIAA PACE Hardware
do
    if [ ! -d "$PANDIR/$repo" ]; then
        echo "Grabbing $repo repo"
        cd $PANDIR && git clone https://github.com/panoptes/${repo}.git >>$PANDIR/bootstrap.log 2>&1
        echo "Adding environmental variable: ${repo}=\$PANDIR/${repo}"
        add_to_bashrc ${repo} "$PANDIR/${repo}"
    fi
done
source $PANHOME/.bashrc

echo "************** Anaconda Python Distribution **************"
if ! hash conda 2>/dev/null ; then
    # This is ~300 MB so may take a while to download
    echo "************** Getting Anaconda **************"
    cd /tmp

    miniconda=Miniconda3-latest-Linux-x86_64.sh
    if [[ ! -f $miniconda ]]; then
        wget http://repo.continuum.io/miniconda/$miniconda >>$PANDIR/bootstrap.log 2>&1
    fi
    chmod +x $miniconda

    if [ ! -d "$ANACONDADIR" ]; then
        echo "************** Creating Anaconda directory **************"
        sudo mkdir -p $ANACONDADIR
        sudo chown -R $PANUSER:$PANUSER $ANACONDADIR

        add_to_bashrc 'ANACONDADIR' $ANACONDADIR
    fi

    bash /tmp/$miniconda -b -fp $ANACONDADIR

    add_to_bashrc 'PATH' '$ANACONDADIR/bin:$PATH'


    # Check your python version
    echo "Checking python version"
    python -V
fi

# Update the anaconda distribution
echo "************** Updating conda **************"
$ANACONDADIR/bin/conda update -y conda >>$PANDIR/bootstrap.log 2>&1

echo "************** Installing python requirements **************"
if [ -f "$POCS/requirements.txt" ]; then
    echo "Installing required python packages for PANOPTES"
    $ANACONDADIR/bin/conda install -y --file $POCS/requirements.txt >>$PANDIR/bootstrap.log 2>&1
fi

echo "************** Updating gphoto2 **************"
if [ ! -f "$PANDIR/gphoto2-updater.sh" ]; then
    # This is a big download so we cache it in main dir
    cd $PANDIR
    wget -q https://raw.githubusercontent.com/gonzalo/gphoto2-updater/master/gphoto2-updater.sh && chmod +x gphoto2-updater.sh
fi
sudo ./gphoto2-updater.sh >>$PANDIR/bootstrap.log 2>&1

echo "************** Checking cdsclient **************"
if ! hash cdsclient 2>/dev/null ; then
    cd /tmp
    wget http://cdsarc.u-strasbg.fr/ftp/pub/sw/cdsclient.tar.gz >>$PANDIR/bootstrap.log 2>&1
    tar -zxvf cdsclient.tar.gz >>$PANDIR/bootstrap.log 2>&1 && cd cdsclient-3.80/ && ./configure >>$PANDIR/bootstrap.log 2>&1 && make >>$PANDIR/bootstrap.log 2>&1 && sudo make install >>$PANDIR/bootstrap.log 2>&1 && cd $HOME
fi

echo "************** Checking scamp **************"
if ! hash scamp 2>/dev/null ; then
    echo "Installing SCAMP"
    cd /tmp && wget http://www.astromatic.net/download/scamp/scamp-2.0.4.tar.gz >>$PANDIR/bootstrap.log 2>&1
    tar -zxvf scamp-2.0.4.tar.gz >>$PANDIR/bootstrap.log 2>&1 && cd scamp-2.0.4
    ./configure \
        --with-atlas-libdir=/usr/lib/atlas-base \
        --with-atlas-incdir=/usr/include/atlas \
        --with-fftw-libdir=/usr/lib \
        --with-fftw-incdir=/usr/include \
        --with-plplot-libdir=/usr/lib \
        --with-plplot-incdir=/usr/include/plplot >>$PANDIR/bootstrap.log 2>&1
    make >>$PANDIR/bootstrap.log 2>&1 && sudo make install >>$PANDIR/bootstrap.log 2>&1
fi

echo "************** Installing SWARP and astrometry.net **************"
sudo aptitude install -y install swarp astrometry.net >>$PANDIR/bootstrap.log 2>&1

if [ ! -f "/usr/share/data/index-4107.fits" ]; then
    echo "************** Getting astrometry.net indicies **************"
    cd /usr/share/data && sudo wget -q -A fits -m -l 1 -nd http://broiler.astrometry.net/~dstn/4100/ >>$PANDIR/bootstrap.log 2>&1
fi

echo "************** Done with Requirements **************"

# Upgrade system
echo "************** Upgrading system **************"
sudo aptitude -y full-upgrade >>$PANDIR/bootstrap.log 2>&1

echo "************** Done with install **************"
