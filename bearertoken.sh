#!/bin/bash

az account get-access-token \
  --resource https://management.azure.com \
  --query accessToken \
  -o tsv