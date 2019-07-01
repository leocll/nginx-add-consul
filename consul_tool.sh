#!/bin/bash

RED_T="\033[31m"
GREEN_T="\033[32m"
YOLLOW_T="\033[33m"
END_T="\033[0m"

tmp_path="${HOME}/nginx+consul"
consul_path="${tmp_path}/consul"
consul_url="https://releases.hashicorp.com/consul/1.5.2/consul_1.5.2_linux_amd64.zip"
install_path="/usr/local/consul"
host_ad="127.0.0.1"

### download
load_consul() {
	local url="${consul_url}"
	local path="${consul_path}"
	[[ -n "${url}" ]] || { echo -e "${RED_T}[error]: download consul, url is null.${END_T}";return 1;}
	[[ -n "${path}" ]] || { echo -e "${RED_T}[error]: download consul, path is null.${END_T}";return 1;}

	[[ -d "${tmp_path}" ]] || { mkdir -p "${tmp_path}" || return 1;}
	[[ -d "${consul_path}" ]] && { rm -rf "${consul_path}" || return 1;}

	pushd "${tmp_path}" &> /dev/null
	local pack_name="${url##*/}"
	wget -O "${pack_name}" "${url}" \
	&& unzip "${pack_name}" -d "${consul_path}" \
	&& rm "${pack_name}" || { popd &> /dev/null;return 1;}
	popd &> /dev/null
}

### install
install() {
	sudo mv "${consul_path}" "${install_path}" || return $?
}

#### add to source
add2source() {
	[[ -n "$(command -v consul)" ]] || { sudo ln -s "${install_path}/consul" "/usr/local/bin/" || return $?;}
	return 0
}

### start
start() {
	[[ -n "${node_name}" ]] || { echo -e "${RED_T}[error]: start consul, node is null.${END_T}";return 1;}
	[[ -n "${host_ad}" ]] || { echo -e "${RED_T}[error]: start consul, host is null.${END_T}";return 1;}
	[[ -d "${install_path}/log" ]] || mkdir "${install_path}/log"
	`setsid consul agent -server -bootstrap-expect=1 -data-dir=${install_path}/data -node=${node_name} -bind=${host_ad} -client 0.0.0.0 -ui \
	>> "${install_path}/log/consul.log" 2>&1 &` ||return 1
}

### add 
add() {
	[[ -n "${node_name}" ]] || { echo -e "${RED_T}[error]: start consul, node is null.${END_T}";return 1;}
	[[ -n "${server_ad_p}" ]] || { echo -e "${RED_T}[error]: start consul, server is null.${END_T}";return 1;}
	local body=""
	[[ -n "${server_config}" ]] && body="-d '${server_config}'"
	# curl -X PUT -d '{"weight":10, "max_fails":2, "fail_timeout":10, "down":0}' http://127.0.0.1:8500/v1/kv/upstreams/testnode/127.0.0.1:8899
	curl -X PUT ${body} http://127.0.0.1:8500/v1/kv/upstreams/${node_name}/${server_ad_p} || return 1
}

### remove
remove() {
	[[ -n "${node_name}" ]] || { echo -e "${RED_T}[error]: start consul, node is null.${END_T}";return 1;}
	[[ -n "${server_ad_p}" ]] || { echo -e "${RED_T}[error]: start consul, server is null.${END_T}";return 1;}
	# curl -X DELETE  http://127.0.0.1:8500/v1/kv/upstreams/testnode/127.0.0.1:8899
	curl -X DELETE http://127.0.0.1:8500/v1/kv/upstreams/${node_name}/${server_ad_p} || return 1
}


if [[ -z "${BASH_SOURCE[1]}" ]]; then
	print_help() {
		echo -e "Use info: '${BASH_SOURCE[0]} [command] [option]'"
		echo -e "[command]          [information]"
		echo -e "install            Download and install."
		echo -e "start              Start consul."
		echo -e "add                Add server for node."
		echo -e "remove             Remove server for node."
		echo -e "uninstall          Uninstall consul."
		echo -e "clear              Clear source code and compile information."
		echo -e "-h|--help          use information."
	}
	print_install_help() {
		echo -e "Use info:"
		echo -e "${BASH_SOURCE[0]} install [option]"
		# echo -e "--install-path text    Install path, the default is ${YOLLOW_T}${install_path}${END_T}."
		echo -e "-u|--url text          Source code url, the default is ${YOLLOW_T}${consul_url}${END_T}."
		echo -e "-h|--help              use information."
	}
	print_start_help() {
		echo -e "Use info:"
		echo -e "${BASH_SOURCE[0]} install [node]"
		echo -e "[node]                 Node name."
		echo -e "--host                 Bind IP, the default is ${YOLLOW_T}${host_ad}${END_T}"
		echo -e "-h|--help              use information."
	}
	print_add_help() {
		echo -e "Use info:"
		echo -e "${BASH_SOURCE[0]} add [node] [server]"
		echo -e "[node]                 Node name."
		echo -e "[server]               Server address and port."
		echo -e "-c|--config            Server config."
		echo -e "-h|--help              use information."
	}
	print_remove_help() {
		echo -e "Use info:"
		echo -e "${BASH_SOURCE[0]} remove [node] [server]"
		echo -e "[node]                 Node name."
		echo -e "[server]               Server address and port."
		echo -e "-h|--help              use information."
	}
	node_name=""
	server_ad_p=""
	case $1 in
		install|start|add|remove|uninstall|clear )
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
			-u|--url )
				consul_url=$2
				shift 2
				;;
			--install-path )
				install_path=$2
				shift 2
				;;
			--host )
				host_ad=$2
				shift 2
				;;
			-c|--config )
				server_config=$2
				shift 2
				;;
			-h|--help )
				case ${COMMAND} in
					install )
						print_install_help
						;;
					start )
						print_start_help
						;;
					add )
						print_add_help
						;;
					remove )
						print_remove_help
						;;
					uninstall )
						echo -e "Use info: "
						echo -e "${YOLLOW_T}${BASH_SOURCE[0]} uninstall${END_T}  Uninstall consul."
						;;
					clear )
						echo -e "Use info: "
						echo -e "${YOLLOW_T}${BASH_SOURCE[0]} clear${END_T}      Clear tmp information."
						;;
					* )
						echo -e "${RED_T}Invalid option: $1${END_T}"
						print_help
						;;
				esac
				exit 0 
				;;
			* )
				if [[ -n "$1" ]] && [[ -z "${node_name}" || -z "${server_ad_p}" ]]; then
					[[ -z "${node_name}" ]] && node_name=$1 || server_ad_p=$1
					shift
				else
					print_help
					exit 1
				fi
				;;
		esac
	done
	if [[ "${COMMAND}" == "install" ]]; then 
		load_consul && install && add2source || exit 1
	elif [[ "${COMMAND}" == "start" ]]; then
		start || exit 1
	elif [[ "${COMMAND}" == "add" ]]; then
		add || exit 1
	elif [[ "${COMMAND}" == "remove" ]]; then
		remove || exit 1
	elif [[ "${COMMAND}" == "uninstall" ]]; then
		[[ -d "${install_path}" ]] && sudo rm -rf "${install_path}" || exit 1
	elif [[ "${COMMAND}" == "clear" ]]; then
		[[ -d "${tmp_path}" ]] && rm -rf "${tmp_path}" || exit 1
	else
		print_help
	fi
fi