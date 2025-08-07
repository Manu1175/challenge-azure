#!/bin/bash

# Variables
RESOURCE_GROUP="ressource_emmanuel"
LOCATION="germanywestcentral"
STORAGE_ACCOUNT="irailstorage001"
PLAN_NAME="getraildata-plan"
FUNCTION_APP="getraildata"
RUNTIME="python"
FUNCTION_VERSION="4"
SKU="B1"

echo "✅ Création du groupe de ressources..."
az group create --name $RESOURCE_GROUP --location $LOCATION

echo "✅ Création du compte de stockage..."
az storage account create \
  --name $STORAGE_ACCOUNT \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_LRS

echo "✅ Création du plan d’hébergement (SKU $SKU)..."
az functionapp plan create \
  --name $PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku $SKU \
  --is-linux

echo "✅ Création de l’Azure Function App..."
az functionapp create \
  --name $FUNCTION_APP \
  --storage-account $STORAGE_ACCOUNT \
  --plan $PLAN_NAME \
  --resource-group $RESOURCE_GROUP \
  --functions-version $FUNCTION_VERSION \
  --runtime $RUNTIME \
  --os-type Linux

echo "✅ Configuration des variables d'environnement..."
az functionapp config appsettings set \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --settings \
    AzureWebJobsFeatureFlags=EnableWorkerIndexing \
    SCM_DO_BUILD_DURING_DEPLOYMENT=true

# Vérifie si host.json est présent sinon le créer
if [ ! -f "host.json" ]; then
  echo "✅ Création du fichier host.json manquant..."
  echo '{ "version": "2.0" }' > host.json
else
  echo "✅ Fichier host.json déjà présent."
fi

echo "✅ Publication de la Function App..."
func azure functionapp publish $FUNCTION_APP --python --build local

echo "🚀 Déploiement terminé ! URL de l'app : https://$FUNCTION_APP.azurewebsites.net"
