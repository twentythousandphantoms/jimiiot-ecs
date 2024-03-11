Jimi-iot
=

These are Terraform scripts for deploying jimi-iot platform in AWS ECS. 


How to run: 
- 

1. Set up aws cli and credentials. You can create ".dev-env" file with the following:
```
export AWS_ACCESS_KEY_ID="<your key id>"
export AWS_SECRET_ACCESS_KEY="<your secret>"
```

2. Deploy using terraform:
```
$bash deploy.sh i # for terraform init  
$bash deploy.sh p # for terraform plan  
$bash deploy.sh a # for terraform apply  
$bash deploy.sh d # for terraform destroy  
```

TODO: 
* Create a better solution to put the license file inside the containers
Some ideas for this -  
1. install awscli during container startup by customizing entrypoint command,  
2. or attach a volume containing the license to the containers  
2.1 this requires developing a separate satellite container which has  
2.1.a the license file baked inside it  
2.1.b or aws cli installed and script to download the license file from s3/aws secrets  


* Dive deeper into the specifics and requirements of the jimi components and satisfy to make everything work (and there is not enough documentation on this, unfortunately)
* Develop load balancing and autoscaling
* Adapt everything (especially networking) to your infrastructure and account.

