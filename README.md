# wp-automation
Scripts for WP automation

asdadd


userful docker command to start my dev db

docker run    --name test-mysql    -v /mnt/k8volumes/mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=strong_password  -p 13306:3306 -d mysql:9.0.1 && docker logs  test-mysql -f


docker login:
/usr/local/aws-cli/v2/current/bin/aws --profile <> ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin <>.dkr.ecr.eu-west-1.amazonaws.com/<>

/usr/local/aws-cli/v2/current/bin/aws --profile wpuser ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/y7c9l5j8


/usr/local/aws-cli/v2/current/bin/aws --profile wpuser ecr-public get-login-password -
-region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/y7c9l5j8


glab auth login

hostname: oxford.awsdev.infor.com/

choose token and give it the token from https://oxford.awsdev.infor.com/-/user_settings/personal_access_tokens?page=1&state=active&sort=expires_asc

export GITLAB_HOST=oxford.awsdev.infor.com 

GITLAB_HOST=oxford.awsdev.infor.com  glab api "groups/albanero/projects?include_subgroups=true&per_page=1000&visibility=private" \
| jq -r '.[] | .ssh_url_to_repo' \
| while read repo; \
do \
echo "Cloning $repo"; \
git clone "$repo";  \
done

#listing the projects and subgroups
GITLAB_HOST=oxford.awsdev.infor.com  glab repo list --group <your-group> --include-subgroups --per-page 1000