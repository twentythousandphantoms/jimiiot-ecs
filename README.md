Jimi-iot
=

These are Terraform scripts for deploying jimi-iot platmorn in AWS ECS. 


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




