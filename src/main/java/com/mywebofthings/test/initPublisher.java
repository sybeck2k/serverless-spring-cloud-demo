package com.mywebofthings.test;

import com.amazonaws.regions.Regions;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mywebofthings.test.publisher.LogPublisher;
import com.mywebofthings.test.publisher.PrintLogPublisher;
import com.mywebofthings.test.publisher.SnsLogPublisher;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.core.env.Environment;

@Configuration
public class initPublisher {

  @Autowired
  private ObjectMapper objectMapper;

  @Bean
  public LogPublisher printLogPublisher() {
    return new PrintLogPublisher();
  }

  @Bean
  @Primary
  @ConditionalOnProperty("sns.topicArn")
  public LogPublisher snsLogPublisher(Environment env) {
    String snsTopicArn = env.getRequiredProperty("sns.topicArn");
    String awsRegionName = env.getRequiredProperty("sns.region");
    return new SnsLogPublisher(snsTopicArn, Regions.fromName(awsRegionName), objectMapper);
  }

}
