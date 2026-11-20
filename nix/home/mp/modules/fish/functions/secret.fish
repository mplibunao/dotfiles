function secret --description "Generate a random 32-character hex secret"
    # Uses node to generate a random hex string
    # Same as your zsh version
    node -e "console.log(crypto.randomBytes(16).toString('hex'))"
end