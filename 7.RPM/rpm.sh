
RPM packets

Устанавливаем необходимые пакеты и  зависимости:


[root@rocky96 ~]# dnf install -y wget rpmdevtools rpm-build createrepo \
 yum-utils cmake gcc git nano




Last metadata expiration check: 0:33:30 ago on Thu 30 Oct 2025 05:32:28 PM MSK.
Package wget-1.21.1-8.el9_4.x86_64 is already installed.
Package yum-utils-4.3.0-20.el9.noarch is already installed.
Package nano-5.6.1-7.el9.x86_64 is already installed.
Dependencies resolved.
======================================================================================================================================================================================================= Package                                               Architecture                           Version                                                  Repository                                 Size
=======================================================================================================================================================================================================Installing:
 cmake                                                 x86_64                                 3.26.5-2.el9                                             appstream                                 8.7 M
 createrepo_c                                          x86_64                                 0.20.1-2.el9                                             appstream                                  73 k
 gcc                                                   x86_64                                 11.5.0-5.el9_5                                           appstream                                  32 M
 git                                                   x86_64                                 2.47.3-1.el9_6                                           appstream                                  50 k
 rpm-build                                             x86_64                                 4.16.1.3-37.el9                                          appstream                                  59 k
 rpmdevtools                                           noarch                                 9.5-1.el9                                                appstream                                  75 k
Installing dependencies:
 annobin                                               x86_64                                 12.92-1.el9                                              appstream                                 1.1 M
 cmake-data                                            noarch                                 3.26.5-2.el9                                             appstream                                 1.7 M
 cmake-filesystem                                      x86_64                                 3.26.5-2.el9                                             appstream                                  11 k
 cmake-rpm-macros                                      noarch                                 3.26.5-2.el9                                             appstream                                  10 k
 cpp                                                   x86_64                                 11.5.0-5.el9_5                                           appstream                                  11 M
 createrepo_c-libs                                     x86_64                                 0.20.1-2.el9                                             appstream                                  99 k
 debugedit                                             x86_64                                 5.0-5.el9                                                appstream                                  76 k
 dwz                                                   x86_64                                 0.14-3.el9                                               appstream                                 127 k
 efi-srpm-macros                                       noarch                                 6-2.el9_0                                                appstream                                  22 k
 elfutils                                              x86_64                                 0.192-6.el9_6                                            baseos                                    560 k
 fonts-srpm-macros                                     noarch                                 1:2.0.5-7.el9.1                                          appstream                                  27 k
 gcc-plugin-annobin                                    x86_64                                 11.5.0-5.el9_5                                           appstream                                  39 k
 gdb-minimal                                           x86_64                                 14.2-4.1.el9_6                                           appstream                                 4.2 M
 ghc-srpm-macros                                       noarch                                 1.5.0-6.el9                                              appstream                                 7.8 k
 git-core                                              x86_64                                 2.47.3-1.el9_6                                           appstream                                 4.6 M
 git-core-doc                                          noarch                                 2.47.3-1.el9_6                                           appstream                                 2.8 M
 glibc-devel                                           x86_64                                 2.34-168.el9_6.23                                        appstream                                  32 k
 glibc-headers                                         x86_64                                 2.34-168.el9_6.23                                        appstream                                 437 k
 go-srpm-macros                                        noarch                                 3.6.0-10.el9_6                                           appstream                                  26 k
 kernel-headers                                        x86_64                                 5.14.0-570.55.1.el9_6                                    appstream                                 3.3 M
 kernel-srpm-macros                                    noarch                                 1.0-13.el9                                               appstream                                  15 k
 libmpc                                                x86_64                                 1.2.1-4.el9                                              appstream                                  61 k
 libxcrypt-devel                                       x86_64                                 4.4.18-3.el9                                             appstream                                  28 k
 lua-srpm-macros                                       noarch                                 1-6.el9                                                  appstream                                 8.5 k
 make                                                  x86_64                                 1:4.3-8.el9                                              baseos                                    529 k
 ocaml-srpm-macros                                     noarch                                 6-6.el9                                                  appstream                                 7.8 k
 openblas-srpm-macros                                  noarch                                 2-11.el9                                                 appstream                                 7.3 k
 patch                                                 x86_64                                 2.7.6-16.el9                                             appstream                                 127 k
 perl-DynaLoader                                       x86_64                                 1.47-481.1.el9_6                                         appstream                                  24 k
 perl-Error                                            noarch                                 1:0.17029-7.el9                                          appstream                                  41 k
 perl-File-Find                                        noarch                                 1.37-481.1.el9_6                                         appstream                                  24 k
 perl-Git                                              noarch                                 2.47.3-1.el9_6                                           appstream                                  37 k
 perl-TermReadKey                                      x86_64                                 2.38-11.el9                                              appstream                                  36 k
 perl-lib                                              x86_64                                 0.65-481.1.el9_6                                         appstream                                  13 k
 perl-srpm-macros                                      noarch                                 1-41.el9                                                 appstream                                 8.2 k
 pyproject-srpm-macros                                 noarch                                 1.16.2-1.el9                                             appstream                                  13 k
 python-srpm-macros                                    noarch                                 3.9-54.el9                                               appstream                                  17 k
 qt5-srpm-macros                                       noarch                                 5.15.9-1.el9                                             appstream                                 7.9 k
 redhat-rpm-config                                     noarch                                 209-1.el9                                                appstream                                  66 k
 rust-srpm-macros                                      noarch                                 17-4.el9                                                 appstream                                 9.3 k
 zstd                                                  x86_64                                 1.5.5-1.el9                                              baseos                                    461 k

Transaction Summary
=======================================================================================================================================================================================================Install  47 Packages

[root@rocky96 ~]# mkdir rpm && cd rpm

[root@rocky96 rpm]# yumdownloader --source nginx
enabling epel-source repository
enabling epel-cisco-openh264-source repository
enabling baseos-source repository
enabling appstream-source repository
enabling extras-source repository
Waiting for process with pid 7785 to finish.
Extra Packages for Enterprise Linux 9 - x86_64 - Source                              [===                                                                            ] ---  B/s |   0  B     --:-- ETExtra Packages for Enterprise Linux 9 - x86_64 - Source                                                                                                                1.8 MB/s | 4.1 MB     00:02    
Extra Packages for Enterprise Linux 9 openh264 (From Cisco) - x86_64 - Source                                                                                          700  B/s | 1.2 kB     00:01    
Rocky Linux 9 - BaseOS - Source                                                                                                                                        332 kB/s | 276 kB     00:00    
Rocky Linux 9 - AppStream - Source                                                                                                                                     1.8 MB/s | 1.1 MB     00:00    
Rocky Linux 9 - Extras Source                                                                                                                                           45 kB/s |  14 kB     00:00    
nginx-1.20.1-22.el9_6.3.src.rpm                                                                                                                                         12 MB/s | 1.1 MB     00:00  

Ставим все зависимости для сборки пакета Nginx

[root@rocky96 rpm]# rpm -Uvh nginx*.src.rpm
Updating / installing...
   1:nginx-2:1.20.1-22.el9_6.3        warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
warning: user mockbuild does not exist - using root
warning: group mock does not exist - using root
################################# [100%]

[root@rocky96 rpm]# yum-builddep nginx


Installed:
  brotli-1.0.9-7.el9_5.x86_64                        brotli-devel-1.0.9-7.el9_5.x86_64               bzip2-devel-1.0.8-10.el9_5.x86_64           fontconfig-devel-2.14.0-2.el9_1.x86_64              
  freetype-devel-2.10.4-10.el9_5.x86_64              gd-2.3.2-3.el9.x86_64                           gd-devel-2.3.2-3.el9.x86_64                 glib2-devel-2.68.4-16.el9_6.2.x86_64                
  graphite2-devel-1.3.14-9.el9.x86_64                harfbuzz-devel-2.7.4-10.el9.x86_64              harfbuzz-icu-2.7.4-10.el9.x86_64            jbigkit-libs-2.1-23.el9.x86_64                      
  libICE-1.0.10-8.el9.x86_64                         libSM-1.2.3-10.el9.x86_64                       libX11-devel-1.7.0-11.el9.x86_64            libX11-xcb-1.7.0-11.el9.x86_64                      
  libXau-devel-1.0.9-8.el9.x86_64                    libXpm-3.5.13-10.el9.x86_64                     libXpm-devel-3.5.13-10.el9.x86_64           libXt-1.2.0-6.el9.x86_64                            
  libblkid-devel-2.37.4-21.el9.x86_64                libffi-devel-3.4.2-8.el9.x86_64                 libgpg-error-devel-1.42-5.el9.x86_64        libicu-devel-67.1-10.el9_6.x86_64                   
  libjpeg-turbo-devel-2.0.90-7.el9.x86_64            libmount-devel-2.37.4-21.el9.x86_64             libpng-devel-2:1.6.37-12.el9.x86_64         libselinux-devel-3.6-3.el9.x86_64                   
  libsepol-devel-3.6-2.el9.x86_64                    libtiff-4.4.0-13.el9.x86_64                     libtiff-devel-4.4.0-13.el9.x86_64           libwebp-1.2.0-8.el9.x86_64                          
  libwebp-devel-1.2.0-8.el9.x86_64                   libxcb-devel-1.13.1-9.el9.x86_64                libxml2-devel-2.9.13-12.el9_6.x86_64        libxslt-devel-1.1.34-13.el9_6.x86_64                
  openssl-devel-1:3.2.2-6.el9_5.1.x86_64             pcre-cpp-8.44-4.el9.x86_64                      pcre-devel-8.44-4.el9.x86_64                pcre-utf16-8.44-4.el9.x86_64                        
  pcre-utf32-8.44-4.el9.x86_64                       pcre2-devel-10.40-6.el9.x86_64                  pcre2-utf16-10.40-6.el9.x86_64              pcre2-utf32-10.40-6.el9.x86_64                      
  perl-AutoSplit-5.74-481.1.el9_6.noarch             perl-Benchmark-1.23-481.1.el9_6.noarch          perl-CPAN-Meta-2.150010-460.el9.noarch      perl-CPAN-Meta-Requirements-2.140-461.el9.noarch    
  perl-CPAN-Meta-YAML-0.018-461.el9.noarch           perl-Devel-PPPort-3.62-4.el9.x86_64             perl-Encode-Locale-1.05-21.el9.noarch       perl-ExtUtils-Command-2:7.60-3.el9.noarch           
  perl-ExtUtils-Constant-0.25-481.1.el9_6.noarch     perl-ExtUtils-Embed-1.35-481.1.el9_6.noarch     perl-ExtUtils-Install-2.20-4.el9.noarch     perl-ExtUtils-MakeMaker-2:7.60-3.el9.noarch         
  perl-ExtUtils-Manifest-1:1.73-4.el9.noarch         perl-ExtUtils-ParseXS-1:3.40-460.el9.noarch     perl-Fedora-VSP-0.001-23.el9.noarch         perl-File-Compare-1.100.600-481.1.el9_6.noarch      
  perl-File-Copy-2.34-481.1.el9_6.noarch             perl-I18N-Langinfo-0.19-481.1.el9_6.x86_64      perl-JSON-PP-1:4.06-4.el9.noarch            perl-Math-BigInt-1:1.9998.18-460.el9.noarch         
  perl-Math-Complex-1.59-481.1.el9_6.noarch          perl-Test-Harness-1:3.42-461.el9.noarch         perl-Time-HiRes-4:1.9764-462.el9.x86_64     perl-devel-4:5.32.1-481.1.el9_6.x86_64              
  perl-doc-5.32.1-481.1.el9_6.noarch                 perl-generators-1.13-1.el9.noarch               perl-locale-1.09-481.1.el9_6.noarch         perl-macros-4:5.32.1-481.1.el9_6.noarch             
  perl-version-7:0.99.28-4.el9.x86_64                sysprof-capture-devel-3.40.1-3.el9.x86_64       systemtap-sdt-devel-5.2-2.el9.x86_64        xorg-x11-proto-devel-2024.1-1.el9.noarch            
  xz-devel-5.2.5-8.el9_0.x86_64                      zlib-devel-1.2.11-40.el9.x86_64                

Complete!

[root@rocky96 rpm]#  cd /root

[root@rocky96 ~]# git clone --recurse-submodules -j8 \
https://github.com/google/ngx_brotli

Cloning into 'ngx_brotli'...
remote: Enumerating objects: 237, done.
remote: Counting objects: 100% (37/37), done.
remote: Compressing objects: 100% (16/16), done.
remote: Total 237 (delta 24), reused 21 (delta 21), pack-reused 200 (from 1)
Receiving objects: 100% (237/237), 79.51 KiB | 848.00 KiB/s, done.
Resolving deltas: 100% (114/114), done.
Submodule 'deps/brotli' (https://github.com/google/brotli.git) registered for path 'deps/brotli'
Cloning into '/root/ngx_brotli/deps/brotli'...
remote: Enumerating objects: 8755, done.        
remote: Counting objects: 100% (381/381), done.        
remote: Compressing objects: 100% (225/225), done.        
remote: Total 8755 (delta 236), reused 158 (delta 156), pack-reused 8374 (from 3)        
Receiving objects: 100% (8755/8755), 45.81 MiB | 15.88 MiB/s, done.
Resolving deltas: 100% (5600/5600), done.
Submodule path 'deps/brotli': checked out 'ed738e842d2fbdf2d6459e39267a633c4a9b2f5d'

Собираем модуль ngx_brotli:

[root@rocky96 out]# cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
-- The C compiler identification is GNU 11.5.0
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Check for working C compiler: /bin/cc - skipped
-- Detecting C compile features
-- Detecting C compile features - done
-- Build type is 'Release'
-- Performing Test BROTLI_EMSCRIPTEN
-- Performing Test BROTLI_EMSCRIPTEN - Failed
-- Compiler is not EMSCRIPTEN
-- Looking for log2
-- Looking for log2 - not found
-- Looking for log2
-- Looking for log2 - found
-- Configuring done (0.9s)
-- Generating done (0.0s)
CMake Warning:
  Manually-specified variables were not used by the project:

    CMAKE_CXX_FLAGS


-- Build files have been written to: /root/ngx_brotli/deps/brotli/out


[root@rocky96 out]# cmake --build . --config Release -j 2 --target brotlienc

[  3%] Building C object CMakeFiles/brotlicommon.dir/c/common/constants.c.o
[  6%] Building C object CMakeFiles/brotlicommon.dir/c/common/context.c.o
[ 10%] Building C object CMakeFiles/brotlicommon.dir/c/common/platform.c.o
[ 13%] Building C object CMakeFiles/brotlicommon.dir/c/common/dictionary.c.o
[ 17%] Building C object CMakeFiles/brotlicommon.dir/c/common/shared_dictionary.c.o
[ 20%] Building C object CMakeFiles/brotlicommon.dir/c/common/transform.c.o
[ 24%] Linking C static library libbrotlicommon.a
[ 24%] Built target brotlicommon
[ 31%] Building C object CMakeFiles/brotlienc.dir/c/enc/backward_references_hq.c.o
[ 31%] Building C object CMakeFiles/brotlienc.dir/c/enc/backward_references.c.o
[ 34%] Building C object CMakeFiles/brotlienc.dir/c/enc/bit_cost.c.o
[ 37%] Building C object CMakeFiles/brotlienc.dir/c/enc/block_splitter.c.o
[ 41%] Building C object CMakeFiles/brotlienc.dir/c/enc/brotli_bit_stream.c.o
[ 44%] Building C object CMakeFiles/brotlienc.dir/c/enc/cluster.c.o
[ 48%] Building C object CMakeFiles/brotlienc.dir/c/enc/command.c.o
[ 51%] Building C object CMakeFiles/brotlienc.dir/c/enc/compound_dictionary.c.o
[ 55%] Building C object CMakeFiles/brotlienc.dir/c/enc/compress_fragment.c.o
[ 58%] Building C object CMakeFiles/brotlienc.dir/c/enc/compress_fragment_two_pass.c.o
[ 62%] Building C object CMakeFiles/brotlienc.dir/c/enc/dictionary_hash.c.o
[ 65%] Building C object CMakeFiles/brotlienc.dir/c/enc/encode.c.o
[ 68%] Building C object CMakeFiles/brotlienc.dir/c/enc/encoder_dict.c.o
[ 72%] Building C object CMakeFiles/brotlienc.dir/c/enc/entropy_encode.c.o
[ 75%] Building C object CMakeFiles/brotlienc.dir/c/enc/fast_log.c.o
[ 79%] Building C object CMakeFiles/brotlienc.dir/c/enc/histogram.c.o
[ 82%] Building C object CMakeFiles/brotlienc.dir/c/enc/literal_cost.c.o
[ 86%] Building C object CMakeFiles/brotlienc.dir/c/enc/memory.c.o
[ 89%] Building C object CMakeFiles/brotlienc.dir/c/enc/metablock.c.o
[ 93%] Building C object CMakeFiles/brotlienc.dir/c/enc/static_dict.c.o
[ 96%] Building C object CMakeFiles/brotlienc.dir/c/enc/utf8_util.c.o
[100%] Linking C static library libbrotlienc.a
[100%] Built target brotlienc

[root@rocky96 out]# cd ../../../..

[root@rocky96 ~]# nano /root/rpmbuild/SPECS/nginx.spec
...--add-module=/root/ngx_brotli \...

Собираем пакет 

[root@rocky96 SPECS]#  rpmbuild -ba nginx.spec -D 'debug_package %{nil}'

Executing(%clean): /bin/sh -e /var/tmp/rpm-tmp.xeQKvD
+ umask 022
+ cd /root/rpmbuild/BUILD
+ cd nginx-1.20.1
+ /usr/bin/rm -rf /root/rpmbuild/BUILDROOT/nginx-1.20.1-22.el9.3.x86_64
+ RPM_EC=0
++ jobs -p
+ exit 0


Убедимся, что пакеты создались:

[root@rocky96 x86_64]# ll ~/rpmbuild/RPMS/x86_64
total 1988
-rw-r--r--. 1 root root   36953 Oct 30 18:28 nginx-1.20.1-22.el9.3.x86_64.rpm
-rw-r--r--. 1 root root 1019635 Oct 30 18:28 nginx-core-1.20.1-22.el9.3.x86_64.rpm
-rw-r--r--. 1 root root  759971 Oct 30 18:28 nginx-mod-devel-1.20.1-22.el9.3.x86_64.rpm
-rw-r--r--. 1 root root   20118 Oct 30 18:28 nginx-mod-http-image-filter-1.20.1-22.el9.3.x86_64.rpm
-rw-r--r--. 1 root root   31569 Oct 30 18:28 nginx-mod-http-perl-1.20.1-22.el9.3.x86_64.rpm
-rw-r--r--. 1 root root   18850 Oct 30 18:28 nginx-mod-http-xslt-filter-1.20.1-22.el9.3.x86_64.rpm
-rw-r--r--. 1 root root   54448 Oct 30 18:28 nginx-mod-mail-1.20.1-22.el9.3.x86_64.rpm
-rw-r--r--. 1 root root   81019 Oct 30 18:28 nginx-mod-stream-1.20.1-22.el9.3.x86_64.rpm

Копируем пакеты в общий каталог:

[root@rocky96 x86_64]#  cp ~/rpmbuild/RPMS/noarch/* ~/rpmbuild/RPMS/x86_64/
[root@rocky96 x86_64]# cd ~/rpmbuild/RPMS/x86_64


Устанавливаем наш пакет.



[root@rocky96 x86_64]# dnf localinstall *.rpm
Last metadata expiration check: 0:25:08 ago on Thu 30 Oct 2025 06:08:55 PM MSK.
Dependencies resolved.
======================================================================================================================================================================================================= Package                                                    Architecture                          Version                                            Repository                                   Size
=======================================================================================================================================================================================================Installing:
 nginx                                                      x86_64                                2:1.20.1-22.el9.3                                  @commandline                                 36 k
 nginx-all-modules                                          noarch                                2:1.20.1-22.el9.3                                  @commandline                                7.8 k
 nginx-core                                                 x86_64                                2:1.20.1-22.el9.3                                  @commandline                                996 k
 nginx-filesystem                                           noarch                                2:1.20.1-22.el9.3                                  @commandline                                9.4 k
 nginx-mod-devel                                            x86_64                                2:1.20.1-22.el9.3                                  @commandline                                742 k
 nginx-mod-http-image-filter                                x86_64                                2:1.20.1-22.el9.3                                  @commandline                                 20 k
 nginx-mod-http-perl                                        x86_64                                2:1.20.1-22.el9.3                                  @commandline                                 31 k
 nginx-mod-http-xslt-filter                                 x86_64                                2:1.20.1-22.el9.3                                  @commandline                                 18 k
 nginx-mod-mail                                             x86_64                                2:1.20.1-22.el9.3                                  @commandline                                 53 k
 nginx-mod-stream                                           x86_64                                2:1.20.1-22.el9.3                                  @commandline                                 79 k
Installing dependencies:
 rocky-logos-httpd                                          noarch                                90.16-1.el9                                        appstream                                    24 k

Transaction Summary
=======================================================================================================================================================================================================Install  11 Packages

Total size: 2.0 M
Total download size: 24 k
Installed size: 9.6 M


[root@rocky96 x86_64]# systemctl start nginx
[root@rocky96 x86_64]# systemctl status nginx

● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: disabled)
     Active: active (running) since Thu 2025-10-30 18:34:58 MSK; 4s ago
    Process: 37691 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 37692 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 37693 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 37694 (nginx)
      Tasks: 5 (limit: 23114)
     Memory: 8.2M
        CPU: 84ms
     CGroup: /system.slice/nginx.service
             ├─37694 "nginx: master process /usr/sbin/nginx"
             ├─37695 "nginx: worker process"
             ├─37696 "nginx: worker process"
             ├─37697 "nginx: worker process"
             └─37698 "nginx: worker process"

Oct 30 18:34:58 rocky96.kauh.ru systemd[1]: Starting The nginx HTTP and reverse proxy server...
Oct 30 18:34:58 rocky96.kauh.ru nginx[37692]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Oct 30 18:34:58 rocky96.kauh.ru nginx[37692]: nginx: configuration file /etc/nginx/nginx.conf test is successful
Oct 30 18:34:58 rocky96.kauh.ru systemd[1]: Started The nginx HTTP and reverse proxy server.


Теперь приступим к созданию своего репозитория. Директория для статики у Nginx по умолчанию /usr/share/nginx/html. Создадим там каталог repo:

[root@rocky96 x86_64]#  mkdir /usr/share/nginx/html/repo

Копируем туда наши собранные RPM-пакеты:

[root@rocky96 x86_64]# cp ~/rpmbuild/RPMS/x86_64/*.rpm /usr/share/nginx/html/repo/

Инициализируем репозиторий командой:

[root@rocky96 x86_64]# createrepo /usr/share/nginx/html/repo/
Directory walk started
Directory walk done - 10 packages
Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
Preparing sqlite DBs
Pool started (with 5 workers)
Pool finished


[root@rocky96 x86_64]# nano /etc/nginx/nginx.conf

    server {
        listen       80;
        listen       [::]:80;
        server_name  _;
        root         /usr/share/nginx/html;
+       index index.html index.htm;
+       autoindex on;

[root@rocky96 x86_64]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful


[root@rocky96 x86_64]# nginx -s reload

[root@rocky96 x86_64]#  curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          30-Oct-2025 15:37                   -
<a href="nginx-1.20.1-22.el9.3.x86_64.rpm">nginx-1.20.1-22.el9.3.x86_64.rpm</a>                   30-Oct-2025 15:36               36953
<a href="nginx-all-modules-1.20.1-22.el9.3.noarch.rpm">nginx-all-modules-1.20.1-22.el9.3.noarch.rpm</a>       30-Oct-2025 15:36                8029
<a href="nginx-core-1.20.1-22.el9.3.x86_64.rpm">nginx-core-1.20.1-22.el9.3.x86_64.rpm</a>              30-Oct-2025 15:36             1019635
<a href="nginx-filesystem-1.20.1-22.el9.3.noarch.rpm">nginx-filesystem-1.20.1-22.el9.3.noarch.rpm</a>        30-Oct-2025 15:36                9666
<a href="nginx-mod-devel-1.20.1-22.el9.3.x86_64.rpm">nginx-mod-devel-1.20.1-22.el9.3.x86_64.rpm</a>         30-Oct-2025 15:36              759971
<a href="nginx-mod-http-image-filter-1.20.1-22.el9.3.x86_64.rpm">nginx-mod-http-image-filter-1.20.1-22.el9.3.x86..&gt;</a> 30-Oct-2025 15:36               20118
<a href="nginx-mod-http-perl-1.20.1-22.el9.3.x86_64.rpm">nginx-mod-http-perl-1.20.1-22.el9.3.x86_64.rpm</a>     30-Oct-2025 15:36               31569
<a href="nginx-mod-http-xslt-filter-1.20.1-22.el9.3.x86_64.rpm">nginx-mod-http-xslt-filter-1.20.1-22.el9.3.x86_..&gt;</a> 30-Oct-2025 15:36               18850
<a href="nginx-mod-mail-1.20.1-22.el9.3.x86_64.rpm">nginx-mod-mail-1.20.1-22.el9.3.x86_64.rpm</a>          30-Oct-2025 15:36               54448
<a href="nginx-mod-stream-1.20.1-22.el9.3.x86_64.rpm">nginx-mod-stream-1.20.1-22.el9.3.x86_64.rpm</a>        30-Oct-2025 15:36               81019
</pre><hr></body>
</html>

[root@rocky96 x86_64]#  cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF
[root@rocky96 x86_64]# dnf repolist enabled | grep otus
otus                 otus-linux


Добавим пакет в наш репозиторий:

[root@rocky96 x86_64]# cd /usr/share/nginx/html/repo/
[root@rocky96 repo]# wget https://repo.percona.com/yum/percona-release-latest.noarch.rpm
--2025-10-30 18:43:15--  https://repo.percona.com/yum/percona-release-latest.noarch.rpm

Resolving repo.percona.com (repo.percona.com)... 49.12.125.205, 2a01:4f8:242:5792::2
Connecting to repo.percona.com (repo.percona.com)|49.12.125.205|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 28532 (28K) [application/x-redhat-package-manager]
Saving to: ‘percona-release-latest.noarch.rpm’

percona-release-latest.noarch.rpm                 100%[============================================================================================================>]  27.86K  --.-KB/s    in 0.001s  

2025-10-30 18:43:16 (48.6 MB/s) - ‘percona-release-latest.noarch.rpm’ saved [28532/28532]

[root@rocky96 repo]# 
[root@rocky96 repo]# createrepo /usr/share/nginx/html/repo/
Directory walk started
Directory walk done - 11 packages
Temporary output repo path: /usr/share/nginx/html/repo/.repodata/
Preparing sqlite DBs
Pool started (with 5 workers)
Pool finished
[root@rocky96 repo]# dnf  makecache
Extra Packages for Enterprise Linux 9 - x86_64                                                                                                                         171 kB/s |  36 kB     00:00    
Extra Packages for Enterprise Linux 9 openh264 (From Cisco) - x86_64                                                                                                   2.2 kB/s | 993  B     00:00    
otus-linux                                                                                                                                                             269 kB/s | 7.2 kB     00:00    
Rocky Linux 9 - BaseOS                                                                                                                                                  15 kB/s | 4.1 kB     00:00    
Rocky Linux 9 - AppStream                                                                                                                                               18 kB/s | 4.5 kB     00:00    
Rocky Linux 9 - Extras                                                                                                                                                  11 kB/s | 2.9 kB     00:00    
Zabbix Official Repository - x86_64                                                                                                                                    3.9 kB/s | 3.0 kB     00:00    
Zabbix Official Repository (non-supported) - x86_64                                                                                                                    3.8 kB/s | 2.9 kB     00:00    
Zabbix Official Repository (tools) - x86_64                                                                                                                            3.8 kB/s | 3.0 kB     00:00    
Metadata cache created.
[root@rocky96 repo]# dnf list | grep otus
percona-release.noarch                                                                   1.0-32                               otus     


Так как Nginx у нас уже стоит, установим репозиторий percona-release:

[root@rocky96 repo]# dnf install -y percona-release.noarch
Last metadata expiration check: 0:01:18 ago on Thu 30 Oct 2025 06:43:44 PM MSK.
Dependencies resolved.
======================================================================================================================================================================================================= Package                                                Architecture                                  Version                                        Repository                                   Size
=======================================================================================================================================================================================================Installing:
 percona-release                                        noarch                                        1.0-32                                         otus                                         28 k

Transaction Summary
=======================================================================================================================================================================================================Install  1 Package