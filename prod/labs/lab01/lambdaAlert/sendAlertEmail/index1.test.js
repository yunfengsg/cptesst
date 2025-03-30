/* eslint-disable no-undef */
const aws = require('aws-sdk');
const { handler } = require('./index1'); // replace with your actual file name

jest.mock('aws-sdk', () => {
    const sendEmailMock = jest.fn().mockReturnValue({
        promise: jest.fn().mockResolvedValue({})
    });
    
    return {
        SES: jest.fn(() => ({
            sendEmail: sendEmailMock
        }))
    };
});

describe('SES Email Sending', () => {
    // Reset mocks before each test
    beforeEach(() => {
        jest.clearAllMocks();
    });

    it('should send an email when actual value exceeds threshold', async () => {
        const event = {
            Records: [
                {
                    eventName: 'INSERT',
                    dynamodb: {
                        NewImage: {
                            Plant: { S: 'Plant1' },
                            Line: { S: 'Line1' },
                            KpiValue: { N: '110' },
                            ThresholdValue: { N: '100' },
                            KpiName: { S: 'Production Rate' }
                        }
                    }
                }
            ]
        };
        
        await handler(event);
        
        // Check if sendEmail was called correctly
        expect(aws.SES().sendEmail).toHaveBeenCalled();
        expect(aws.SES().sendEmail).toHaveBeenCalledWith(expect.objectContaining({
            Destination: {
                ToAddresses: ["chekyeaw+ce8@gmail.com"]
            },
            Message: {
                Body: {
                    Text: {
                        Charset: "UTF-8",
                        Data: 'Production Rate has exceeded the threshold value 100 by 10 units for plant Plant1 and line Line1'
                    }
                },
                Subject: {
                    Charset: "UTF-8",
                    Data: "KPI Alert"
                }
            },
            Source: "chekyeaw@gmail.com"
        }));
    });

    it('should not send an email when actual value is within threshold', async () => {
        const event = {
            Records: [
                {
                    eventName: 'INSERT',
                    dynamodb: {
                        NewImage: {
                            Plant: { S: 'Plant1' },
                            Line: { S: 'Line1' },
                            KpiValue: { N: '90' }, // Below threshold
                            ThresholdValue: { N: '100' },
                            KpiName: { S: 'Production Rate' }
                        }
                    }
                }
            ]
        };
        
        await handler(event);
        
        // Check sendEmail was not called
        expect(aws.SES().sendEmail).not.toHaveBeenCalled();
    });

    it('should ignore REMOVE event', async () => {
        const event = {
            Records: [
                {
                    eventName: 'REMOVE',
                    dynamodb: {}
                }
            ]
        };
        
        await handler(event);
        
        // We should simply return without sending an email
        expect(aws.SES().sendEmail).not.toHaveBeenCalled();
    });
});

  