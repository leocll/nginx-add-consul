#!/bin/bash

RED_T="\033[31m"
GREEN_T="\033[32m"
YOLLOW_T="\033[33m"
END_T="\033[0m"

tmp_path="${HOME}/nginx+consul"
src_dir="nginx"
src_url="http://nginx.org/download/nginx-1.16.0.tar.gz"
upsync_module_path="${tmp_path}/nginx-upsync-module"
upsync_module_url="https://github.com/weibocom/nginx-upsync-module/archive/v2.1.0.tar.gz"
install_path="/usr/local/nginx"

### download
load_file() {
	local url=$1
	local path=$2
	[[ -n "${url}" ]] || { echo -e "${RED_T}[error]: download file, url is null.${END_T}";return 1;}
	[[ -n "${path}" ]] || { echo -e "${RED_T}[error]: download file, path is null.${END_T}";return 1;}

	[[ -d "${tmp_path}/tmp" ]] && { rm -rf "${tmp_path}/tmp" || return 1;}
	mkdir -p "${tmp_path}/tmp" || return 1;

	pushd "${tmp_path}" &> /dev/null
	local pack_name="${url##*/}"
	wget -O "${pack_name}" "${url}" \
	&& tar zxvf "${pack_name}" -C "tmp" \
	&& mv "tmp/$(cd tmp;ls)" "${path}" \
	&& rm "${pack_name}" && rm -rf "tmp" || { popd &> /dev/null;return 1;}
	popd &> /dev/null
}

#### download source code
load_src() {
	load_file "${src_url}" "${tmp_path}/${src_dir}" || return $?
}

#### download nginx-upsync-module
load_upsync_module() {
	load_file "${upsync_module_url}" "${upsync_module_path}" || return $?
}

#### install libraries
install_lib() {
	sudo apt-get update || return 1
	# gcc g++
	sudo apt-get install build-essential libtool || return 1
	# pcre
	sudo apt-get install libpcre3 libpcre3-dev || return 1
	# zlib
	sudo apt-get install zlib1g-dev || return 1
	# ssl
	sudo apt-get install openssl || return 1
}

#### compile and install
make_and_install() {
	pushd "${src_path}" &> /dev/null
	# ngx_http_limit_conn_module
	[[ -d "./ngx_http_limit_conn_module" ]]  || { mkdir "./ngx_http_limit_conn_module" || return 1;}
	[[ -f "./ngx_http_limit_conn_module/config" ]]  || { touch "./ngx_http_limit_conn_module/config" || return 1;}
	# ngx_http_limit_req_module
	[[ -d "./ngx_http_limit_req_module" ]]  || { mkdir "./ngx_http_limit_req_module" || return 1;}
	[[ -f "./ngx_http_limit_req_module/config" ]]  || { touch "./ngx_http_limit_req_module/config" || return 1;}

	# ./configure \
	# --prefix="${install_path}" \
	# --user=nginx \
	# --group=nginx \
	# --with-http_realip_module \
	# --with-http_ssl_module \
	# --with-http_stub_status_module \
	# --with-http_gzip_static_module \
	# --add-module=ngx_http_limit_conn_module \
	# --add-module=ngx_http_limit_req_module \
	# --add-module="${upsync_module_path}" || exit 1
	./configure \
	--prefix="${install_path}" \
	--with-http_realip_module \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_gzip_static_module \
	--add-module=ngx_http_limit_conn_module \
	--add-module=ngx_http_limit_req_module \
	--add-module="${upsync_module_path}" || exit 1

	make && sudo make install && echo -e "${GREEN_T}Installed in ${install_path}${END_T}"
	popd &> /dev/null
}

#### add to source
add2source() {
	[[ -n "$(command -v nginx)" ]] || { sudo ln -s "${install_path}/sbin/nginx" "/usr/local/bin/" || return $?;}
	return 0
}

if [[ -z "${BASH_SOURCE[1]}" ]]; then
	print_help() {
		echo -e "Use info: '${BASH_SOURCE[0]} [command] [option]'"
		echo -e "[command]          [information]"
		echo -e "install            Compile and install."
		echo -e "uninstall          Uninstall nginx."
		echo -e "clear              Clear source code and compile information."
		echo -e "-h|--help          use information."
	}
	print_install_help() {
		echo -e "Use info:"
		echo -e "${YOLLOW_T}${BASH_SOURCE[0]} install --scr-path [xxx]${END_T}"
		echo -e "                        Compile and install with local source code."
		echo -e "${YOLLOW_T}${BASH_SOURCE[0]} install -u [xxx]${END_T}"
		echo -e "                        Download source code with url, compile and install."
		echo -e "--src-path text         Source code path."
		# echo -e "--install-path text     Install path, the default is ${YOLLOW_T}${install_path}${END_T}."
		echo -e "-u|--url text           Source code url, the default is ${YOLLOW_T}${src_url}${END_T}."
		echo -e "-h|--help               use information."
	}
	case $1 in
		install|uninstall|clear )
			COMMAND=$1
			shift
			;;
		-h|--help )
			print_help
			exit 0
			;;
		* )
			[[ -n "$1" ]] && echo -e "${RED_T}Invalid option: $1${END_T}"
			print_help
			exit 1
			;;
	esac
	while [[ $# -ge 1 ]]; do
		case $1 in
			--src-path )
				src_path=$2
				shift 2
				;;
			-u|--url )
				src_url=$2
				shift 2
				;;
			--install-path )
				install_path=$2
				shift 2
				;;
			-h|--help )
				case ${COMMAND} in
					install )
						print_install_help
						;;
					uninstall )
						echo -e "Use info: "
						echo -e "${YOLLOW_T}${BASH_SOURCE[0]} uninstall${END_T}  Uninstall nginx."
						;;
					clear )
						echo -e "Use info: "
						echo -e "${YOLLOW_T}${BASH_SOURCE[0]} clear${END_T}      Clear source code and compile information."
						;;
					* )
						echo -e "${RED_T}Invalid option: $1${END_T}"
						print_help
						;;
				esac
				exit 0 
				;;
			* )
				print_help
				exit 1
				;;
		esac
	done
	if [[ "${COMMAND}" == "install" ]]; then 
		[[ -n "${src_path}" ]] || { load_src && src_path="${tmp_path}/${src_dir}" || exit 1;}
		install_lib && load_upsync_module && make_and_install && add2source || exit 1
	elif [[ "${COMMAND}" == "uninstall" ]]; then
		[[ -d "${install_path}" ]] && sudo rm -rf "${install_path}" || exit 1
	elif [[ "${COMMAND}" == "clear" ]]; then
		[[ -d "${tmp_path}" ]] && rm -rf "${tmp_path}" || exit 1
	else
		print_help
	fi
fi


