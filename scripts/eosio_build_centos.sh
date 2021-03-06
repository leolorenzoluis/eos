	OS_VER=$( cat /etc/os-release | grep VERSION_ID | cut -d'=' -f2 | sed 's/[^0-9\.]//gI' \
	| cut -d'.' -f1 )

	MEM_MEG=$( free -m | grep Mem | tr -s ' ' | cut -d\  -f2 )

	CPU_SPEED=$( lscpu | grep "MHz" | tr -s ' ' | cut -d\  -f3 | cut -d'.' -f1 )
	CPU_CORE=$( lscpu | grep "^CPU(s)" | tr -s ' ' | cut -d\  -f2 )

	DISK_INSTALL=`df -h . | tail -1 | tr -s ' ' | cut -d\  -f1`
	DISK_TOTAL_KB=`df . | tail -1 | awk '{print $2}'`
	DISK_AVAIL_KB=`df . | tail -1 | awk '{print $4}'`
	DISK_TOTAL=$(( $DISK_TOTAL_KB / 1048576 ))
	DISK_AVAIL=$(( $DISK_AVAIL_KB / 1048576 ))

	printf "\n\tOS name: $OS_NAME\n"
	printf "\tOS Version: ${OS_VER}\n"
	printf "\tCPU speed: ${CPU_SPEED}Mhz\n"
	printf "\tCPU cores: $CPU_CORE\n"
	printf "\tPhysical Memory: $MEM_MEG Mgb\n"
	printf "\tDisk install: ${DISK_INSTALL}\n"
	printf "\tDisk space total: ${DISK_TOTAL%.*}G\n"
	printf "\tDisk space available: ${DISK_AVAIL%.*}G\n"

	if [ $MEM_MEG -lt 4000 ]; then
		echo "Your system must have 4 or more Gigabytes of physical memory installed."
		echo "exiting now."
		exit 1
	fi

	if [ $OS_VER -lt 7 ]; then
		echo "You must be running Centos 7 or higher to install EOSIO."
		echo "exiting now"
		exit 1
	fi

	if [ ${DISK_AVAIL%.*} -lt $DISK_MIN ]; then
		echo "You must have at least ${DISK_MIN}GB of available storage to install EOSIO."
		echo "exiting now"
		exit 1
	fi
	printf "\n\tChecking Yum installation\n"
	
	YUM=$( which yum 2>/dev/null )
	if [ $? -ne 0 ]; then
		printf "\n\tYum must be installed to compile EOS.IO.\n"
		printf "\n\tExiting now.\n"
		exit 0
	fi
	
	printf "\tYum installation found at ${YUM}.\n"
	printf "\n\tChecking installation of Centos Software Collections Repository.\n"
	
	SCL=$( which scl 2>/dev/null )
	if [ -z $SCL ]; then
		printf "\n\tThe Centos Software Collections Repository, devtoolset-7 and Python3 are required to install EOSIO.\n"
		printf "\tDo you wish to install and enable this repository, devtoolset-7 and Python3 packages?\n"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* ) 
					printf "\n\n\tInstalling SCL.\n\n"
					sudo yum -y --enablerepo=extras install centos-release-scl 2>/dev/null
					if [ $? -ne 0 ]; then
						printf "\n\tCentos Software Collections Repository installation failed.\n"
						printf "\n\tExiting now.\n"
						exit 1
					else
						printf "\n\tCentos Software Collections Repository installed successfully.\n"
					fi
					printf "\n\n\tInstalling devtoolset-7.\n\n"
					sudo yum install -y devtoolset-7 2>/dev/null
					if [ $? -ne 0 ]; then
						printf "\n\tCentos devtoolset-7 installation failed.\n"
						printf "\n\tExiting now.\n"
						exit 1
					else
						printf "\n\tCentos devtoolset installed successfully.\n"
					fi
					printf "\n\n\tInstalling Python3.\n\n"
					sudo yum install -y python33.x86_64 2>/dev/null
					if [ $? -ne 0 ]; then
						printf "\n\tCentos Python3 installation failed.\n"
						printf "\n\tExiting now.\n"
						exit 1
					else
						printf "\n\tCentos Python3 installed successfully.\n"
					fi
				break;;
				[Nn]* ) echo "User aborting installation of required Centos Software Collections Repository, Exiting now."; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else 
		printf "\n\tCentos Software Collections Repository found.\n"
	fi

	printf "\n\tEnabling Centos devtoolset-7.\n"
	source /opt/rh/devtoolset-7/enable
	if [ $? -ne 0 ]; then
		printf "\n\tUnable to enable Centos devtoolset-7 at this time.\n"
		printf "\n\tExiting now.\n"
		exit 1
	fi
	printf "\tCentos devtoolset-7 successfully enabled.\n"

	printf "\n\tEnabling Centos python3 installation.\n"
	source /opt/rh/python33/enable
	if [ $? -ne 0 ]; then
		printf "\n\tUnable to enable Centos python3 at this time.\n"
		printf "\n\tExiting now.\n"
		exit 1
	fi
	printf "\tCentos python3 successfully enabled.\n"
	
	printf "\n\tUpdating YUM repository.\n"

	sudo yum -y update 2>/dev/null
	
	if [ $? -ne 0 ]; then
		printf "\n\tYUM update failed.\n"
		printf "\n\tExiting now.\n"
		exit 1
	fi

	printf "\n\tYUM repository successfully updated.\n"

	DEP_ARRAY=( git autoconf automake libtool ocaml.x86_64 doxygen libicu-devel.x86_64 \
	bzip2-devel.x86_64 openssl-devel.x86_64 gmp-devel.x86_64 python-devel.x86_64 gettext-devel.x86_64)
	COUNT=1
	DISPLAY=""
	DEP=""

	printf "\n\tChecking YUM for installed dependencies.\n\n"

	for (( i=0; i<${#DEP_ARRAY[@]}; i++ ));
	do
		pkg=$( sudo $YUM info ${DEP_ARRAY[$i]} 2>/dev/null | grep Repo | tr -s ' ' | cut -d: -f2 | sed 's/ //g' )

		if [ "$pkg" != "installed" ]; then
			DEP=$DEP" ${DEP_ARRAY[$i]} "
			DISPLAY="${DISPLAY}${COUNT}. ${DEP_ARRAY[$i]}\n\t"
			printf "\tPackage ${DEP_ARRAY[$i]} ${bldred} NOT ${txtrst} found.\n"
			let COUNT++
		else
			printf "\tPackage ${DEP_ARRAY[$i]} found.\n"
			continue
		fi
	done		

	if [ ${COUNT} -gt 1 ]; then
		printf "\n\tThe following dependencies are required to install EOSIO.\n"
		printf "\n\t$DISPLAY\n\n"
		printf "\tDo you wish to install these dependencies?\n"
		select yn in "Yes" "No"; do
			case $yn in
				[Yy]* ) 
					printf "\n\n\tInstalling dependencies\n\n"
					sudo yum -y install ${DEP}
					if [ $? -ne 0 ]; then
						printf "\n\tYUM dependency installation failed.\n"
						printf "\n\tExiting now.\n"
						exit 1
					else
						printf "\n\tYUM dependencies installed successfully.\n"
					fi
				break;;
				[Nn]* ) echo "User aborting installation of required dependencies, Exiting now."; exit;;
				* ) echo "Please type 1 for yes or 2 for no.";;
			esac
		done
	else 
		printf "\n\tNo required YUM dependencies to install.\n"
	fi

	printf "\n\tChecking CMAKE installation.\n"
    if [ ! -e ${CMAKE} ]; then
		printf "\tInstalling CMAKE\n"
		mkdir -p ${HOME}/opt/ 2>/dev/null
		cd ${HOME}/opt
		curl -L -O https://cmake.org/files/v3.10/cmake-3.10.2.tar.gz
		tar xf cmake-3.10.2.tar.gz
		rm -f cmake-3.10.2.tar.gz
		ln -s cmake-3.10.2/ cmake
		cd cmake
		./bootstrap
		if [ $? -ne 0 ]; then
			printf "\tError running bootstrap for CMAKE.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		make
		if [ $? -ne 0 ]; then
			printf "\tError compiling CMAKE.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
	else
		printf "\tCMAKE found\n"
	fi

	printf "\n\tChecking boost library installation.\n"
	if [ ! -d ${HOME}/opt/boost_1_66_0 ]; then
		printf "\tInstalling boost libraries\n"
		cd ${TEMP_DIR}
		curl -L https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.bz2 > boost_1.66.0.tar.bz2
		tar xf boost_1.66.0.tar.bz2
		cd boost_1_66_0/
		./bootstrap.sh "--prefix=$BOOST_ROOT"
		./b2 install
		rm -rf ${TEMP_DIR}/boost_1_66_0/
		rm -f  ${TEMP_DIR}/boost_1.66.0.tar.bz2
	else
		printf "\tBoost 1.66 found at ${HOME}/opt/boost_1_66_0\n"
	fi

	printf "\n\tChecking MongoDB installation.\n"
    if [ ! -e ${MONGOD_CONF} ]; then
		printf "\n\tInstalling MongoDB 3.6.3.\n"
		cd ${HOME}/opt
		curl -OL https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-amazon-3.6.3.tgz
		if [ $? -ne 0 ]; then
			printf "\tUnable to download MongoDB at this time.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		tar xf mongodb-linux-x86_64-amazon-3.6.3.tgz
		rm -f mongodb-linux-x86_64-amazon-3.6.3.tgz
		ln -s ${HOME}/opt/mongodb-linux-x86_64-amazon-3.6.3/ ${HOME}/opt/mongodb
		mkdir ${HOME}/opt/mongodb/data
		mkdir ${HOME}/opt/mongodb/log
		touch ${HOME}/opt/mongodb/log/mongod.log
		
tee > /dev/null ${MONGOD_CONF} <<mongodconf
systemLog:
 destination: file
 path: ${HOME}/opt/mongodb/log/mongod.log
 logAppend: true
 logRotate: reopen
net:
 bindIp: 127.0.0.1,::1
 ipv6: true
storage:
 dbPath: ${HOME}/opt/mongodb/data
mongodconf

	else
		printf "\tMongoDB config found at ${MONGOD_CONF}.\n"
	fi

	printf "\n\tChecking MongoDB C++ driver installation.\n"
    if [ ! -e /usr/local/lib/libmongocxx-static.a ]; then
		printf "\n\tInstalling MongoDB C & C++ drivers.\n"
		cd ${TEMP_DIR}
		curl -LO https://github.com/mongodb/mongo-c-driver/releases/download/1.9.3/mongo-c-driver-1.9.3.tar.gz
		if [ $? -ne 0 ]; then
			rm -f ${TEMP_DIR}/mongo-c-driver-1.9.3.tar.gz 2>/dev/null
			printf "\tUnable to download MondgDB C driver at this time.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		tar xf mongo-c-driver-1.9.3.tar.gz
		rm -f ${TEMP_DIR}/mongo-c-driver-1.9.3.tar.gz
		cd mongo-c-driver-1.9.3
		./configure --enable-static --with-libbson=bundled --enable-ssl=openssl --disable-automatic-init-and-cleanup --prefix=/usr/local
		if [ $? -ne 0 ]; then
			printf "\tConfiguring MondgDB C driver has encountered the errors above.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		make -j${CPU_CORE}
		if [ $? -ne 0 ]; then
			printf "\tError compiling MondgDB C driver.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		sudo make install
		if [ $? -ne 0 ]; then
			printf "\tError installing MondgDB C driver.\nMake sure you have sudo privileges.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		cd ..
		rm -rf ${TEMP_DIR}/mongo-c-driver-1.9.3
		cd ${TEMP_DIR}
		sudo rm -rf ${TEMP_DIR}/mongo-cxx-driver
		git clone https://github.com/mongodb/mongo-cxx-driver.git --branch releases/stable --depth 1
		if [ $? -ne 0 ]; then
			printf "\tUnable to clone MondgDB C++ driver at this time.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		cd mongo-cxx-driver/build
		${CMAKE} -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local ..
		if [ $? -ne 0 ]; then
			printf "\tCmake has encountered the above errors building the MongoDB C++ driver.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		sudo make -j${CPU_CORE}
		if [ $? -ne 0 ]; then
			printf "\tError compiling MondgDB C++ driver.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		sudo make install
		if [ $? -ne 0 ]; then
			printf "\tError installing MondgDB C++ driver.\nMake sure you have sudo privileges.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		cd
		sudo rm -rf ${TEMP_DIR}/mongo-cxx-driver
	else
		printf "\tMongo C++ driver found at /usr/local/lib/libmongocxx-static.a.\n"
	fi	

	printf "\n\tChecking secp256k1-zkp installation.\n"
    if [ ! -e /usr/local/lib/libsecp256k1.a ]; then
		printf "\tInstalling secp256k1-zkp (Cryptonomex branch)\n"
		cd ${TEMP_DIR}
		git clone https://github.com/cryptonomex/secp256k1-zkp.git
		cd secp256k1-zkp
		./autogen.sh
		if [ $? -ne 0 ]; then
			printf "\tError running autogen for secp256k1-zkp.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		./configure
		make
		if [ $? -ne 0 ]; then
			printf "\tError compiling secp256k1-zkp.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		sudo make install
		rm -rf cd ${TEMP_DIR}/secp256k1-zkp
	else
		printf "\tsecp256k1 found\n"
	fi
	
	printf "\n\tChecking binaryen installation.\n"
	if [ ! -d ${HOME}/opt/binaryen ]; then
		printf "\tInstalling binaryen v1.37.14:\n"
		cd ${TEMP_DIR}
		git clone https://github.com/EOSIO/binaryen
		cd binaryen
		git checkout eosio
		$CMAKE . && make
		if [ $? -ne 0 ]; then
			printf "\tError compiling binaryen.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		mkdir -p ${HOME}/opt/binaryen/ 2>/dev/null
		mv ${TEMP_DIR}/binaryen/bin ${HOME}/opt/binaryen/
		rm -rf ${TEMP_DIR}/binaryen
	else
		printf "\tBinaryen found at ${HOME}/opt/binaryen\n"
	fi

	printf "\n\tChecking LLVM with WASM support installation.\n"
	if [ ! -d ${HOME}/opt/wasm/bin ]; then
		printf "\tInstalling LLVM & WASM\n"
		cd ${TEMP_DIR}
		mkdir llvm-compiler  2>/dev/null
		cd llvm-compiler
		git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/llvm.git
		cd llvm/tools
		git clone --depth 1 --single-branch --branch release_40 https://github.com/llvm-mirror/clang.git
		cd ..
		mkdir build 2>/dev/null
		cd build
		$CMAKE -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX=${HOME}/opt/wasm \
		-DLLVM_TARGETS_TO_BUILD="host" -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly \
		-DLLVM_ENABLE_RTTI=1 -DCMAKE_BUILD_TYPE=Release ../
		if [ $? -ne 0 ]; then
			printf "\tError compiling LLVM and clang with EXPERIMENTAL WASM support.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		make -j$(nproc)
		if [ $? -ne 0 ]; then
			printf "\tError compiling LLVM and clang with EXPERIMENTAL WASM support.\n"
			printf "\tExiting now.\n\n"
			exit;
		fi
		make install
		rm -rf ${TEMP_DIR}/llvm-compiler 2>/dev/null
	else
		printf "\tWASM found at ${HOME}/opt/wasm\n"
	fi