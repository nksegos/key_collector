# crypto_2019

## Usage
./key_collector.sh -m <strong>\<MODE\>  -p \<PAYLOAD\></strong>

### PARAMETERS
- <strong> MODE </strong>: Can be "local", "remote" or "github_user". Depending on the locality of the repository to be checked or if all the repositories of a specific github user are to be checked.  
- <strong> PAYLOAD </strong>: Can be a directory path, a url or a github username, respectively to the <strong> MODE </strong> parameter. 

### DEFAULTS
- <strong> MODE </strong>: local
- <strong> PAYLOAD </strong>: $PWD
## Things that can be added
Cookie, if you think that some of this shit is unneeded just cross it off and of course if you feel like something's missing, add it below.

- (<strong>UNEEDED</strong>)Parallelism on user-based processing.
- (<strong>UNEEDED</strong>)Multiple types of processing with one script execution through parameter file.
- (<strong>UNEEDED</strong>)Parallelism for the idea above ^^.
- (<strong>IMPLEMENTED AS OPTIONAL KEY PRINT AT THE END OF EXECUTION</strong>)Live printing of found keys on console
- (<strong>DONE</strong>)Grouping of keys on directories named after the repo 
