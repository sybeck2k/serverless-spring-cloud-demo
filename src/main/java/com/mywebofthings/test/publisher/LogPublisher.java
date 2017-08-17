package com.mywebofthings.test.publisher;

import com.mywebofthings.test.LogLine;

public interface LogPublisher {
  void publish(LogLine logLine) throws Exception;
}
