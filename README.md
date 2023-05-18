# gitlab_cli
A simple GitLab CLI tool written in Ruby.

### Usage

#### Searching Projects
```bash
./gitlab_cli.rb --search --project "Project Name"
```

#### Searching Groups
```bash
./gitlab_cli.rb --search --group "Group Name"
```

#### Sharing Projects with a Group
```bash
./gitlab_cli.rb --project "Project Name" --group "Group Name" --access "Access Level"
```

#### Listing Available Access Levels
```bash
./gitlab_cli.rb --list-access-levels
```
