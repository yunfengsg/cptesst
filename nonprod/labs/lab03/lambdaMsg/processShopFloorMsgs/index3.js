const aws = require('aws-sdk')
const ddc = new aws.DynamoDB.DocumentClient()
const tableName = 'shop_floor_alerts'

exports.handler = async (event) => {                                            
    console.log(JSON.stringify(event))

    try {
        for(let item of event.Records){
            await _postData(JSON.parse(item.body))
        }
        
        return _responseHelper(200, "Records inserted successfully!")
    } catch (error) {
        return _responseHelper(404, error.message)
    }
}

const _postData = async (oRequestData) => {
    try {
        let oData = [], count = 0

        for (let [idx, item] of oRequestData.entries()) {

            count++
            oData.push({
                PutRequest: {
                    Item: {
                        ...item,
                        PK: `PLANT#${item.Plant}`,
                        SK: `LINE#${item.Line}#KPI${item.KpiName}`
                    }
                }
            })

            //Batch write rejects request with more than 25 request items
            if (count === 25 || (idx === (oRequestData.length - 1))) {

                await ddc.batchWrite({
                    RequestItems: {
                        [tableName]: oData //Dynamo DB table name
                    }
                }).promise()
                oData = []
                count = 0


            }
        }
    } catch (error) {
        console.log(error)
        throw new Error(error.message)
    }

}

const _responseHelper = (statusCode, payload) => {
    return {
        "statusCode": statusCode,
        "headers": {
            "Access-Control-Allow-Origin": "*"
        },
        "body": payload
    }
}


// Export _postData for testing
module.exports = {
    handler: exports.handler,
    _postData,
};