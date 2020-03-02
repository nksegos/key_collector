# key_collector

A general purpose bash wrapper for extracting private keys for repositories. Done as a semester assignment.

## Usage
./key_collector.sh -m <strong>MODE</strong> -p <strong>PAYLOAD</strong>

### PARAMETERS
- <strong> MODE </strong>: Can be "local", "remote" or "github_user". Depending on the locality of the repository to be checked or if all the repositories of a specific github user are to be checked.  
- <strong> PAYLOAD </strong>: Can be a directory path, a url or a github username, respectively to the <strong> MODE </strong> parameter. 

### DEFAULTS
- <strong> MODE </strong>: local
- <strong> PAYLOAD </strong>: $PWD

