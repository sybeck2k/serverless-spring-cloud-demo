package com.mywebofthings.test.publisher;

import com.amazonaws.regions.Regions;
import com.amazonaws.services.sns.AmazonSNS;
import com.amazonaws.services.sns.AmazonSNSClient;
import com.amazonaws.services.sns.model.PublishRequest;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mywebofthings.test.LogLine;

public class SnsLogPublisher implements LogPublisher{

  private final String topicArn;

  private final AmazonSNS snsClient;

  private ObjectMapper objectMapper;

  public SnsLogPublisher(String topicArn, Regions awsRegion, ObjectMapper objectMapper) {
    this.topicArn = topicArn;
    this.snsClient = AmazonSNSClient.builder().withRegion(awsRegion).build();
    this.objectMapper = objectMapper;
  }

  @Override
  public void publish(LogLine logLine) {
    String msg;
    try {
      msg = objectMapper.writeValueAsString(logLine);
    } catch (JsonProcessingException e) {
      throw new IllegalArgumentException(e);
    }

    PublishRequest publishRequest = new PublishRequest(topicArn, msg);
    snsClient.publish(publishRequest);
  }
}
