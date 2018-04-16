#!/bin/bash
#
# Start/stop an EC2 instance to use as a ssh tunnel and sets up server for NLP tasks
# requires the aws package locally -- sudo apt-get install awscli

set -o nounset
set -o errexit

readonly IMAGE_ID="ami-cb67a4b2"
readonly INSTANCE_TYPE="p2.xlarge"
readonly KEY_NAME="aws-key-fast-ai"
readonly KEY_LOCATION="/home/aws/keypair.pem"
readonly USER="ec2-user"


connect()
{
  getip
  echo "Waiting "$1" seconds"
  sleep "$1"
  echo "SSH tunnelling ..."
  ssh -i "$KEY_LOCATION" "$USER"@"$ip"
}


getip()
{
  ip="$(aws ec2 describe-instances --query "Reservations[*].Instances[*].PublicIpAddress" --output=text)"
  echo "$ip"
}


wait_for_ip()
{
  while true; do
    echo "Waiting "$1" seconds"
    sleep "$1"
    getip
    if [[ ! -z "$ip" ]]; then
      break
    else
      echo "Not found yet. Waiting for "$1" more seconds."
      sleep "$1"
    fi
  done
}


start()
{
  echo "Starting instance..."
  aws ec2 run-instances --image-id $IMAGE_ID --count 1 --instance-type $INSTANCE_TYPE --key-name $KEY_NAME > /dev/null 2>&1
  wait_for_ip 5
  echo "Found IP - Start SSH Tunnelling"

  connect 10
  if [[ $? -ne 0 ]]; then
    echo "SSH Port Forwarding Unsuccessful" >&2
  fi
}


stop()
{
  instance="$(aws ec2 describe-instances --query "Reservations[*].Instances[*].InstanceId" --output=text)"
  aws ec2 terminate-instances --instance-ids $instance
}


send_file_to_server()
{
  getip
  scp -i "$KEY_LOCATION" "$1"  "$USER"@"$ip":/home/ec2-user
}

upgrade_keras_on_server()
{
  getip
  ssh -i "$KEY_LOCATION" "$USER"@"$ip" "sudo pip install --upgrade keras==2.0.6"
}


python_setuptools_on_server()
{
  getip
  ssh -i "$KEY_LOCATION" "$USER"@"$ip" "sudo yum install python-setuptools"
}


python_install_library_on_server()
{
  getip
  ssh -i "$KEY_LOCATION" "$USER"@"$ip" "sudo easy_install "$1""
}


get_glove_embeddings()
{
  getip
  ssh -i "$KEY_LOCATION" "$USER"@"$ip" "wget  "http://nlp.stanford.edu/data/glove.6B.zip" &&\
                                        unzip glove.6B.zip && mkdir glove_embeddings &&\
                                        mv *.txt ./glove_embeddings "
}


instruct()
{
  echo "Please provide an argument: start, stop, resume, connect,
        get_glove_embeddings, python_setuptools_on_server,
        python_install_library_on_server,upgrade_keras_on_server,
        send_file_to_server"
}


#-------------------------------------------------------


# "main"
case "$1" in
  start)
    start
    shift
    ;;
  connect)
    connect $2
    shift
    ;;
  getip)
    getip
    shift
    ;;
  python_setuptools_on_server)
    python_setuptools_on_server
    shift
    ;;
  python_install_library_on_server)
    python_install_library_on_server $2
    shift
    ;;
  send_file_to_server)
    send_file_to_server $2
    shift
    ;;
  stop)
    stop
    shift
    ;;
  upgrade_keras_on_server)
    upgrade_keras_on_server
    shift
    ;;
  get_glove_embeddings)
    get_glove_embeddings
    shift
    ;;
  help|*)
    instruct
    shift
    ;;
esac
shift
