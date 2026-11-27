function gcplogin --description 'Re-authenticate GCP (auth + ADC)'
    echo "==> gcloud auth login"
    gcloud auth login; or return 1
    echo ""
    echo "==> gcloud auth application-default login"
    gcloud auth application-default login
end
