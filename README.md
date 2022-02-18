# Introduction

Deploy AWS EKS via a Jenkins job using terraform. The idea here is to easily deploy EKS to AWS, specifying some settings via pipeline parameters.

`eksctl` has now come along since I wrote this repo, and that is a simpler way of deploying EKS. Thus I created an `eksctl` based deployment [here](https://github.com/spicysomtam/jenkins-deploy-eks-via-eksctl). Both the `eksctl` and this deploy have similar setups, so where there is duplicate, refer to the `eksctl` docs. I am maintaining this repo and the docs here are specific to the `terraform` deploy.

For each cluster the deploy creates a vpc, 3 subnets and some networking infra allowing connection out onto the internet so you can access the cluster remotely. You could adapt it to run on the default vpc, but then there is some danger in having many clusters on the default vpc and then hitting issues with running out of IP addresses.

## Use of EC2 instances via node groups

EC2 instances are used as EKS workers via a node group. An autoscaling group is defined so the number of EC2 instances can be scaled up and down using the Cluster Autoscaler.

# Resources

This is based on the [eks-getting-started](https://github.com/terraform-providers/terraform-provider-aws/tree/master/examples/eks-getting-started) example in the terraform-provider-aws github repo.

Terraform docs are [here](https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html).

AWS docs on EKS are [here](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html).

## Changes made to the aws provider example

Some changes to the aws provider example:

* A lot of the settings have been moved to terraform variables, so we can pass them from Jenkins parameters:
  + aws_region: you specify the region to deploy to (default `eu-west-2`).
  + cluster-name: see below (default `dev-demo`).
  + vpc-network: network part of the vpc; you can have different networks for each of your vpc eks clusters (default `10.0.x.x`).
  + vpc-subnets: number of subnets/az's (default 3).
  + inst-type: Type of instance to deploy as the worker nodes (default `m4.large`).
  + num-workers: Number of workers to deploy (default `3`).
* The cluster name has been changed from `terraform-eks-demo` to `<your-name>`; this means multiple eks instances can be deployed, using different names, from the same Jenkins pipeline.
* The security group providing access to the k8s api has been adapted to allow you to pass cidr addresses to it, so you can customise how it can be accessed. The provider example got your public ip from `http://ipv4.icanhazip.com/`; you are welcome to continue using this!

## Accessing the cluster

Ensure your aws cli is up to date as the new way to access the cluster is via the `aws` cli rather than the `aws-iam-authenticator`, which you used to need to download and install in your path somewhere. Now you can just issue the aws cli to update your kube config:
```
$ aws eks update-kubeconfig --name demo --region eu-west-2
```

You would use `kubectl` to access the cluster (install latest or >= v1.21 at the time of this update). 

Once you can access the cluster via  a test command (eg `kubectl get all -A`), you can add access for other aws users; see official EKS docs [here](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html). 

## Kubernetes api and worker nodes are on the public internet

Just something to be aware of. My view on this is its not very secure, even though all traffic is encypted using TLS and ports are limited. Ideally these should only be accessible on the vpc, and then you need to get access to the vpc via a bastion host or vpn. However this example is intended to be a simple example you can spin up, and maybe enhance to fit your needs.

# Jenkins pipeline

You will need some aws credentials adding to Jenkins to allow access to your AWS account and deploy the terraform stack. Install the `CloudBees AWS Credentials Plugin` plugiin.

Add the git repo where the code is, and tell it to run [Jenkinsfile](Jenkinsfile) as the pipeline.

The pipeline uses a `terraform` workspace for each cluster name, so you should be safe deploying multiple clusters via the same Jenkins job. State is maintained in the Jenkins job workspace (see To do below).

## Terraform tool install

You need to install the `Terraform` plugin in Jenkins, and then define it as a tool in Manage Jenkins->Global Tool Configuration. Check the Jenkinsfile for the version required; for example I setup the tool version as `1.0` for all `1.0.x` releases available; just update the minor version used as newer versions become available. Second digit (eg 1.x) is considered functionality change with terraform so best use labels like `1.0`,`1.1`, etc.

The `create` option creates an EKS cluster stack and `destroy` destroys it.

When running the Jenkins job, you will need to confirm the `create` or `destroy`.

You can create multiple EKS clusters/stacks by simply specifying a different cluster name.

If a `create` goes wrong, simply re-run it for the same cluster name, but choose `destroy`, which will clean it down. Conversly you do the `destroy` when you want to tear down the stack.

## Additional plugin(s)
 You need to install the `AnsiColor` plugin or comment out the line `30`.
# IAM roles required

Several roles are required, which is confusing. Thus decided to document these in simple terms.

Since EKS manages the kubernetes backplane and infrastructure, there are no masters in EKS. When you enter `kubectl get nodes` you will just see the worker nodes that are either implemented via node groups. With other kubernetes platforms, this command will also show Master nodes. Note that as well as using node groups, you can now use fargate, which also shows up as worker nodes via the `kubectl get nodes` command.

Required roles:
* Cluster service role: this is associated with the cluster (and its creation). This allow the Kubernetes control plane to manage AWS resources on behalf of the cluster. The policy `AmazonEKSClusterPolicy` has all the required permissions, so best use that (unless you require a custom setup). The service `eks.amazonaws.com` needs to be able to assume this role (trust relationship). We also attach policy `AmazonEKSVPCResourceController` to the role, to allow security groups for pods (a new eks 1.17 feature; see [this](https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html) for details).
* Node group role: This allows worker nodes to be created for the cluster via an auto scaling group (ASG). The more modern node group replaces the older method of having to create all the resources manually in AWS (ASG, launch configuration, etc). There are three policies that are typically used (interestingly these have not changed since node groups were introduced):
  * AmazonEKSWorkerNodePolicy
  * AmazonEKS_CNI_Policy
  * AmazonEC2ContainerRegistryReadOnly

## Summary of features and options available via the Jenkins pipeline

We can automatically install these features:
* Cloudwatch logging: all cluster backplane logging goes into cloudwatch. Enabled by default.
* Cloudwatch metrics and container insights. This can cost alot of money in terms of aws bills. Thus its default is disabled. Use metrics-server and prometheus instead (and these are better imho).
* Kubernetes dashboard. Some people like this, especially if you are new to k8s, or don't have access to the command line. I would recommend k8s Lens instead, which is a client side program. By default its disabled.
* Prometheus metrics scraper. This is used by various monitoring software (including Lens). By default its enabled
* nginx-ingress. This is discussed elsewhere. Enable an ingress controller, which is extremly useful and thus enabled by default.
* Cluster autoscaler. Spin up and down nodes depending on whether pods are not scheduled (eg the cluster runs out of resources). Only enable for prod deploys and thus disabled by default.
* cert-manager. Automatically manage TLS certs in k8s. Very useful for free Letsencrypt certs (but also works for others such as Godaddy, etc). Disabled by default.

## Kubernetes version can be specified

You can choose all the versions currently offered in the AWS console.

## Automatic setting up of CloudWatch logging, metrics and Container Insights

EKS allows all k8s logging to be sent to CloudWatch logs, which is really useful for investigating issues. I have added an option for this.

In addition, CloudWatch metrics are also gathered from EKS clusters, and these are fed into the recently released Container Insights, which allows you to see graphs on performance, etc. These are not setup automatically in EKS and thus I added this as an option, with the default being disabled. The reason its disabled is because costs can mount on the metrics, while the logging costs are reasonable. Thus you might enable metrics on prod clusters but turn them off on dev clusters.

Note that Container Insights can become expensive to operate; consider installing metrics-server and then some form of scaper and presenter (Prometheus, Kibana, Lens, etc).

## Automatic setup of an ingress controller and a load balancer

The idea here is to set an ingress controller and then just use a single Layer4/TCP style load balancer for all inbound traffic. This is in preference to creating a load balancer for each service, which will create multiple load balancers, incurr additional cost and complexity, and is not necessary! It also makes everything simpler in terms of multiple dns names, certificates, etc; everything is managed in kubernetes rather than a mixed setup of AWS and kubernetes. Trust me; this is the way to go (and I have seen it badly done and then difficult to unravel once setup).

In essence you create a DNS cname record for each service, which points to the load balancer. On ingress the nginx ingress determines the DNS name requested and then directs traffic to the correct service. You can Google kubernetes ingress to discover more about it. Note this setup also supports TLS HTTPS ingress (see TLS in kubernetes documentation on ingress controllers; you can also use wildcard certs, set a default ingress cert, use lets encrypt, etc).

There are multiple ingress controllers available. Most people use the free open source `kubernetes/ingress-nginx`, while confusing ther is another free nginx ingress from Nginx Inc called `nginxinc/kubernetes-ingress`; I used the latter as it has an official AWS Solution documented [here](https://aws.amazon.com/premiumsupport/knowledge-center/eks-access-kubernetes-services/), which has a deployment specifically for AWS. I have simplified the install using the official Helm chart.

Nginx ingress is setup by default, otherwise the EKS cluster has no ingress (just a load balancer for the k8s API). Its a good default if you are not sure what you want and anyway nginx ingress is the way to go with modern k8s!

## cert-manager install

I added the setup of cert-manager, plus installing the ClusterIssuers for Letsencrypt (LE) staging and production using http01 validation method. This means you can use cert-manager to automatically generate LE certificates. 

All you then need to do is point a dns cname record at the load balancer, create a staging cert for it, and then let cert-manager get a cert for you. Sometimes the staging cert does not work first time; if so delete the cert and try again. Once you have a staging cert working, you can replace it with a prod cert, and cert-manager will then manage the cert renewals, etc.

Note: Staging certs won't pass validation on most web browsers while prod ones do. Be aware that prod ones are throttled and controlled more stringely than staging ones; thus why you need to get the staging working first, which will allow you to troubleshoot issues, etc.

See cert manager docs for full details.

## Monitoring and metrics to allow horizontal and vertical pod autoscaling

The horizontal and vertical pod autoscalers need cpu and memory metrics to allow these to operate so you need the metrics-server to be installed for these, which is an option in the Jenkins pipeline.

Prometheus is a common performance scraper used by various monitoring tools (my favourite is k8s Lens); this can now be setup via the Jenkins pipeline.

## kubernetes dashboard

This is a popular gui for those new to k8s or those without access to the command line and kubectl. This can now be installed via the Jenkins pipeline.

## Populating the aws-auth configmap with admin users

After an EKS cluster is created, only the AWS credentials that created the cluster can access it. This is problematic as you may not have the credentials Jenkins used to create the cluster.

Thus you can specify a comma delimited list of IAM users who will be given full admin rights on the cluster.

## Kubernetes Cluster Autoscaler install

I added this as an option (default not enabled). What is it? The kubernetes [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) (CA) allows k8s to scale worker nodes up and down, dependant on load. Since EKS implements worker nodes via node groups and the autoscaling groups (ASG), a deployment within the cluster monitors pod load, and scales up nodes via the ASG when pods are not scheduled (not enough resources available to run them), and scales nodes down again when they are not used (typically after 10 minutes of idle).

Note that there is a max_workers Jenkins parameter; ensure this is large enough as this is the limit that CA can scale to!

Also be aware that the minimum number of nodes will be the same as the desired (num_workers Jenkins parameter). Originally I set the minimum to 1 but the CA will scale down to this with no load which I don't think is a good idea; thus I set the minimum to be the same as desired. You don't want low fault tolerance (one worker) or your cluster to be starved of resources. At a minimum you should have 3 workers, if only to spread them across 3 availability zones, provide some decent capacity and ability to handle some load without waiting for CA to scale more nodes.

Note that you should also consider the Horizontal Pod Autoscaler, which will scale pods up/down based on cpu load (it requires `metrics-server` to aquire metrics to determine load).

### Testing the Cluster Autoscaler

For a complete test we need to test that nodes are scaled up and then down.

#### Scale up

The easiest way to do this is deploy a cluster with a limited number of worker nodes, and then overload them with pods. A simple way to do this is deploy a helm3 chart, and then scale up the number of replicas (pods). 

I found that based on a `m5.large` instance type, using a `nginx` deployment, I could deploy approx 30 pods per worker (pods per node). Lets run through this:

```
$ kubectl get nodes                # We only have one node as I deliberatly set the cluster up like this
NAME                                      STATUS     ROLES    AGE   VERSION
ip-10-0-1-74.eu-west-1.compute.internal   Ready      <none>   46m   v1.17.11-eks-cfdc40

$ kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler # we can check ca logging
$ cd /tmp
$ helm create nginx # This creates a local chart based on nginx
$ helm upgrade ng0 nginx/ --set replicaCount=30 # 1 node overloaded
$ helm upgrade ng0 nginx/ --set replicaCount=60 # 2 nodes overloaded
$ kubeclt get po # Do we have any pending pods?
$ kubectl get nodes # See if we are scaling up; could check the AWS EC2 Console?
```

You should see nodes being added as pods are in pending state. In AWS it can take a couple of minutes to deploy another node. I would increase the number of pods such that you force the addition of 2 nodes.

#### Scale down

We can also check the scale down:
* Reduce the number of pods to 10.
* Wait 10 mins; the ca should start terminating nodes via the auto scaling group.
* If there are pods on nodes that are terminated, kubernetes we kill and restart these on active nodes.
* Needless to say your application should be able to safely restart pods without any side effects!

#### Working round the delay in spinning up another worker

You might ask how can be get round the delay in scaling up another worker? Pods have a priority. You could create a deployment with pods of a lower priority than your default (0); lets call these placeholder pods. Then k8s will kill these placeholder pods and replace them with your regular pods when needed. So you could autoprovision a single node full of these placeholder pods. Your placeholder pods will then become pending after being killed and CA will then spin up another worker for them; since these placeholder pods arn't doing anything useful we don't mind the delay. This is just an idea; I probably need to google a solution where this has been implemented, and provide a link to it (I am sure someone has written something for this).

Another solution: use fargate. However this is not a realistic solution (see my notes above).

# TO DO

I tried to keep it simple as its a proof of concept/example. It probably needs these enhancements:

## Store terraform state in an S3 bucket

This the recommended method, as keeping the stack in the workspace of the Jenkins job is a bad idea! See terraform docs for this. You can probably add a Jenkins parameter for the bucket name, and get the Jenkins job to construct the config for the state before running terraform.

## Implement locking for terraform state using DynamoDB

Similar to state, this ensure multiple runs of terraform cannot happen. See terraform docs for this. Again you might wish to get the dynamodb table name as a Jenkins parameter.
