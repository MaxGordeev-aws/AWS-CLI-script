#!/bin/bash

#Make sure you place files "userdata, alexa.sh, freem.sh" at the same location with this script.
#Pay attention in which region is your AWS CLI is congigured and specify region in the commands if related to different region than your setup. 
#Before you begin, make sure you modify this script with your relevant information. Lines needs to be modified are: 11,13,14,15,16,17.

#________________________________Variables_________________________

region1="us-east-1" #-------------------------------------------------- N.Virginia region.
region2="us-east-2" #-------------------------------------------------- Ohio region.
amazonLinux2AMI="PASTE YOUR AMAZON AMI ID HERE" #---------------------- Amazon free tier AMI - amazon Linux 2.
userdata="nginx_install.txt" #----------------------------------------- User data to install nginx with custom index.html .
ohio_key="PASTE YOUR OHIO KEY NAME HERE"  #---------------------------- us-east-2 key pair (w/o *.pem, just same name as in AWS console).
virginia_key="PASTE YOUR VIRGINIA KEY NAME HERE" #--------------------- us-east-1 key pair (w/o *.pem, just same name as in AWS console).
virg_k_loc="PATH_TO_KEY" #--------------------------------------------- specify path to Virginia key on your PC.
alexash="PATH_TO_ALEXASH_FILE" #--------------------------------------- enter path to alexa.sh file on you PC.
freem="PATH_TO_FREEM_FILE" #------------------------------------------- enter path to freem.sh file on your PC.


echo "Hello user! In this exercise you will learn how to create and modify EC2 instances, copy AMI between regions using AWS CLI and some automation. Good luck!"

sleep 10

#----------------------------US-East-1_N.Virginia region------------

echo "Now we'll create Security Group and launch an EC2 here in Virginia region for you."
# create security group and save returned SG id in a variable
assign8SGid=$(aws ec2 create-security-group --region $region1 --group-name Assign8SG --description "Assignment#8 security group" \
   --query 'GroupId' --output text)

# authorize port 80 & 22 in security group
aws ec2 authorize-security-group-ingress --region $region1 --group-name Assign8SG --protocol tcp --port 80 \
   --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region $region1 --group-name Assign8SG --protocol tcp --port 22 \
   --cidr 0.0.0.0/0

# create an EC2 instance
instance_id=$(aws ec2 run-instances --region $region1 --image-id "$amazonLinux2AMI" \
   --instance-type t2.nano \
   --key-name "$virginia_key" --associate-public-ip-address --user-data file://$userdata \
   --security-group-ids "$assign8SGid" \
   --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Assignment8task1}]' \
   --query 'Instances[*].[InstanceId]' --output text)

aws ec2 wait instance-running --region $region1 --instance-ids $instance_id
IP=$(aws ec2 describe-instances --region $region1 --instance-ids $instance_id \
        --query 'Reservations[].Instances[].PublicIpAddress' --output text)

echo "Wait and Go to the browser check webpage for nginx - you should see something funny :) Copy paste to your browser $IP "

#create AMI from EC2 with NginX
AMI_ID=$(aws ec2 create-image --region $region1 \
    --instance-id "$instance_id" \
    --name "MyServer1" \
    --description "An AMI for my server" \
    --tag-specifications 'ResourceType=image,Tags=[{Key=Name,Value=MyServer1}]' \
    --query 'ImageId' --output text)

aws ec2 wait image-available --region $region1 --image-ids $AMI_ID

echo "Your AMI just created!"

# create 2nd EC2 instance from AMI you just created
image_ec2=$(aws ec2 run-instances --region $region1 --image-id "$AMI_ID" --instance-type t2.nano \
   --key-name "$virginia_key" --associate-public-ip-address \
   --security-group-ids "$assign8SGid" \
   --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Assignment8task2}]' \
   --query 'Instances[*].[InstanceId]' --output text)

aws ec2 wait instance-running --region $region1 --instance-ids $image_ec2

echo "Hang on until your instace will launch...zzzzzz....."

sleep 60

echo "Let's check couple things..."

#getting public ip for 2nd EC2 
YOUR_IP=$(aws ec2 describe-instances --region $region1 --instance-ids $image_ec2 \
        --query 'Reservations[].Instances[].PublicIpAddress' --output text)
echo "Your IP is ready now $YOUR_IP"

#Copy file to instance that will show nginx profile
scp -i $virg_k_loc $alexash ec2-user@$YOUR_IP:/home/ec2-user/alexa.sh 

#SSH to the instance and see alexabuy.jpg
ssh -i $virg_k_loc ec2-user@$YOUR_IP "bash /home/ec2-user/alexa.sh"

echo "Now, let's copy Virginia AMI to Ohio"

#Copy AMI from N.Virginia to the Ohio
IMAGE_OHIO=$(aws ec2 copy-image --source-image-id $AMI_ID \
    --source-region us-east-1 \
    --region us-east-2 \
    --name "MyServer2" \
    --query 'ImageId' --output text)

aws ec2 wait image-available --region $region2 --image-ids $IMAGE_OHIO  
echo "Image id is $IMAGE_OHIO , thanks for waiting."



#----------------------------US-East-2_Ohio_region------------

echo "Now we'll create Security Group and launch an EC2 here in Ohio region for you."

# create security group and save returned SG id in a variable
Ohio_SG=$(aws ec2 create-security-group --region $region2 --group-name Assign8SG --description "Assignment#8 security group --region $region2" \
   --query 'GroupId' --output text)

# authorize port 80 & 22 in security group
aws ec2 authorize-security-group-ingress --region $region2 --group-name Assign8SG --protocol tcp --port 80 \
   --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --region $region2 --group-name Assign8SG --protocol tcp --port 22 \
   --cidr 0.0.0.0/0

#Launch a new instance from copied AMI
Ohio_Instance=$(aws ec2 run-instances --region $region2  \
    --image-id $IMAGE_OHIO  \
    --instance-type t2.nano  \
    --associate-public-ip-address \
    --security-group-ids $Ohio_SG \
    --tag-specifications 'ResourceType=instance, Tags=[{Key=Name, Value=Ohionstance}]' \
    --query 'Instances[*].[InstanceId]' --output text)
aws ec2 wait instance-running --region $region2 --instance-ids $Ohio_Instance

echo "Wait while your instance is launching $Ohio_Instance"
sleep 60s

echo "Need an ip? Here you go..Don't thank me :)"

#get your IP to use to NGINX
OHIO_EC2_IP=$(aws ec2 describe-instances --region $region2 --instance-ids $Ohio_Instance \
        --query 'Reservations[].Instances[].PublicIpAddress' --output text)
echo "Your IP is ready now $OHIO_EC2_IP"


#----------------------------US-East-1_N.Virginia region------------

echo "So now let's play with an instance type and change from t2.nano to t2.micro. First, take a look at current free memory."
sleep 5

#Copy file to instance that will read free memory
scp -i $virg_k_loc $freem ec2-user@$YOUR_IP:/home/ec2-user/freem.sh

#SSH to the instance and see free memory
ssh -i $virg_k_loc ec2-user@$YOUR_IP "bash /home/ec2-user/freem.sh"

sleep 30

#Stop instance before resizing
aws ec2 stop-instances --region $region1 --instance-ids $image_ec2
aws ec2 wait instance-stopped --region $region1 --instance-ids $image_ec2
echo "Stopping your instance"

#resize your instance
aws ec2 modify-instance-attribute --region $region1 --instance-id $image_ec2 --instance-type t2.micro

#start your instance
aws ec2 start-instances --region $region1 --instance-ids $image_ec2
aws ec2 wait instance-running --region $region1 --instance-ids $image_ec2

echo "Wait while your instanse is launching again, you're getting closer to the end!"

sleep 60

echo "Let's ssh to your instance"

#Get your IP to see aftrer resizing
FINISH_IP=$(aws ec2 describe-instances --region $region1 --instance-ids $image_ec2 \
        --query 'Reservations[].Instances[].PublicIpAddress' --output text)
echo "Your IP is ready now $FINISH_IP"

#SSH to the instance and see free memory
ssh -i $virg_k_loc ec2-user@$FINISH_IP "bash /home/ec2-user/freem.sh"

echo "You have completed this Assignment! Now you should have better understanding how thing in AWS works. Good Job, see you next time!"









