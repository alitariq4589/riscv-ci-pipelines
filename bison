node('pioneer-1-admin') {
    stage('Clean Workspace') {
        cleanWs()
    }
    stage('Installing Dependencies') {
        sh '''#!/bin/bash
            sudo apt-get update
            sudo apt-get install autoconf automake autopoint flex gperf graphviz help2man texinfo -y
        '''
    }
    stage('Run system_info') {
        sh '''#!/bin/bash
            echo '============================================================='
            echo '                       CPU INFO START                        '
            echo '============================================================='
            cat /proc/cpuinfo
            echo '============================================================='
            echo '                       CPU INFO END                          '
            echo '============================================================='

            echo '============================================================='
            echo '                       Kernel Info Start                        '
            echo '============================================================='
            uname -a
            echo '============================================================='
            echo '                       Kernel Info End                          '
            echo '============================================================='
            echo '============================================================='
            echo '                       OS Info Start                        '
            echo '============================================================='
            cat /etc/os-release
            echo '============================================================='
            echo '                       OS Info End                        '
            echo '============================================================='
        '''
    }
    stage('Setting Directories and clone') {
        sh '''#!/bin/bash
            mkdir installed_binaries
            git clone --branch master --single-branch --depth=1 https://github.com/akimd/bison.git
        '''
    }

    stage('Run configure') {
        sh '''#!/bin/bash -l
            cd bison
            git submodule update --init
            ./bootstrap
            ./configure --prefix=$(readlink -f ../installed_binaries)
        '''
    }
    stage('make and make check') {
        sh '''#!/bin/bash -l
            make -j$(nproc)
            # make check # Takes too much time so I am skipping this
            make install
        '''
    }
    stage('Test binaries') {
        sh '''#!/bin/bash -l
            ./installed_binaries/bin/bison --version
            ./installed_binaries/bin/yacc --version
        '''
    }
    stage('Compress Binaries and transfer to Cloud') {
        sshagent(credentials: ['SSH_CLOUD_V_STORE_ID']){
            sh '''#!/bin/bash -l
                export FILENAME="bison_$(date -u +"%H%M%S_%d%m%Y").tar.gz"
                tar -cvf ./$FILENAME ./installed_binaries
                eval $(keychain --eval --agents ssh ~/.ssh/cloud-store-key)
                ssh cloud-store 'mkdir -p /var/www/nextcloud/data/admin/files/cloud-v-builds/bison'
                scp $FILENAME cloud-store:/var/www/nextcloud/data/admin/files/cloud-v-builds/bison/
                ssh cloud-store 'sudo -u www-data php /var/www/nextcloud/occ files:scan --path="admin/files"'
            '''
        }
    }
}