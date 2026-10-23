# Creodias object storage

1\. [activate OpenStack CLI](https://creodias.docs.cloudferro.com/en/latest/accountmanagement/How-to-activate-OpenStack-CLI-access-to-Creodias-cloud-using-one-or-two-factor-authentication.html)

In a browser log in to the Creodias portal, open the management console for the cloud region you are using, and download the RC file.

Source the RC file and enter the password and OTP when prompted.

```bash
$ source <rc-file>
Please enter your OpenStack Password for project <project> as user <user>: 
Please enter One-Time Password from your Authenticator App:
```

check the connection by listing the containers

```bash
openstack container list
```

2\. [generate EC2 credentials](https://creodias.docs.cloudferro.com/en/latest/cloud/How-to-generate-ec2-credentials-on-Creodias.html)

```bash
openstack ec2 credentials create -c access -c secret
```

or list credentials with

```bash
openstack ec2 credentials list -c Access -c Secret
```

3\. [configure s3cmd](https://creodias.docs.cloudferro.com/en/latest/s3/How-to-access-private-object-storage-using-S3cmd-or-boto3-on-Creodias.html)

```bash
s3cmd -c s3cfg.txt --configure
```
Be careful to enter the settings correctly for the right cloud region.

the `-c` option specifies where to save the configuration file (default is `~/.s3cfg`)

test the connection

```bash
s3cmd -c s3cfg.txt ls
```

Further information on s3cmd can be found [here](https://creodias.docs.cloudferro.com/en/latest/s3/How-to-access-object-storage-from-Creodias-using-s3cmd.html)

4\. [enable CORS](https://creodias.docs.cloudferro.com/en/latest/networking/How-to-enable-CORS-while-accessing-Object-Storage-Containers-on-Creodias.html)

Check the properties of your container, in this case `leon-p1`.

```bash
$ s3cmd -c s3cfg.txt info s3://leon-p1
s3://leon-p1/ (bucket):
   Location:  default
   Payer:     BucketOwner
   Expiration Rule: none
   Policy:    none
   CORS:      none
   ACL:       cloud_078856_1: FULL_CONTROL
```

enable CORS

```bash
$ s3cmd -c s3cfg.txt setcors cors.xml s3://leon-p1
```

check properties again

```bash
$ s3cmd -c s3cfg.txt info s3://leon-p1
s3://leon-p1/ (bucket):
   Location:  default
   Payer:     BucketOwner
   Expiration Rule: none
   Policy:    none
   CORS:      <CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"><CORSRule><AllowedMethod>GET</AllowedMethod><AllowedOrigin>*</AllowedOrigin><AllowedHeader>*</AllowedHeader></CORSRule></CORSConfiguration>
   ACL:       cloud_078856_1: FULL_CONTROL
```

## Files

Push a directory (recursively) to the container, excluding Python files

```bash
$ s3cmd -c s3cfg.txt put -r --exclude="*.py" ./JRC-GSW s3://leon-p1/
```
