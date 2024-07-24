const AWS = require('aws-sdk');
const dynamo = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) =>{
    console.log('Recieved Event:',JSON.stringify(event,null,2));
    let response;

    switch (event.httpMethod){

        case 'POST' : 
        response = await updateData(event.body);
        break;

        case 'GET' : 
        response = await getData(event.queryStringParameters);
        break;

        default :
        response = {
            statusCode : 405,
            body : JSON.stringify({ message: "Method Not Allowed" })

        }
    }

    return response;
}

async function getData(queryParams){
    console.log("Query Parameters",JSON.stringify(queryParams,null,2));
    if (!queryParams.id){
        console.log("Missing required query paramater 'id'");
        return {
            statusCode : 400,
            body : JSON.stringify({ message: "Missing required query paramater 'id'" })

        }
    }

    const dynamoParams ={
        TableName : "Resumes",
        Key : {
            "ResumeId" : queryParams.id
        }
    };

    console.log("Querying DynamoDB", JSON.stringify(dynamoParams, null, 2));

    try{
        const result = await dynamo.get(dynamoParams).promise();
        console.log("DynamoDB Response", JSON.stringify(result, null, 2));
        if (result.Item){
            console.log("Result Item", JSON.stringify(result.Item, null, 2));
            return {
                statusCode : 200,
                body : JSON.stringify(result.Item),
                headers : {
                    "Content-Type" :"application/json"
                }
            };
        }
        else{
            console.log("Resume not found");
            return {
                statusCode: 404,
                body: JSON.stringify({ message: "Resume not found" })
            };
        }
        
    }
    catch (error) {
        console.error("Error retrieving data: ", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Failed to retrieve data" })
        };
    }

}

async function updateData(data) {
    console.log("Data to update:", JSON.stringify(data, null, 2));
    const dynamoParams = {
        TableName: "Resumes",
        Item: data
    };

    try {
        await dynamo.put(dynamoParams).promise();
        console.log("Data updated successfully");
        return {
            statusCode: 200,
            body: JSON.stringify({ message: "Data updated successfully" })
        };
    } catch (error) {
        console.error("Error updating data:", error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: "Failed to update data" })
        };
    }
}
