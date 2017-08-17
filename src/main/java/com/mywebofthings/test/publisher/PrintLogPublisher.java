package com.mywebofthings.test.publisher;

import com.mywebofthings.test.LogLine;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class PrintLogPublisher implements LogPublisher{

  @Override
  public void publish(LogLine logLine) throws Exception {
    log.info("{}", logLine);
  }
}
