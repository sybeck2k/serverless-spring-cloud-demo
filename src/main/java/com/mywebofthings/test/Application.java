package com.mywebofthings.test;

import com.mywebofthings.test.publisher.LogPublisher;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.util.StringUtils;
import reactor.core.Exceptions;

import java.time.LocalDateTime;
import java.util.Random;
import java.util.function.Function;
import java.util.function.Supplier;

@SpringBootApplication
@Slf4j
public class Application {

  @Autowired
  private LogPublisher logPublisher;

  public static void main(String[] args) {
    SpringApplication.run(Application.class, args);
  }

  @Bean
  public Supplier<LogLine> produceLog() {
    return () -> {
      LogLine logLine = new LogLine();
      logLine.setEventTime(LocalDateTime.now());
      logLine.setMessage(Application.generateRandomWords(10));
      try {
        logPublisher.publish(logLine);
        return logLine;
      } catch (Exception e) {
        log.error("Publisher threw an exception", e);
        throw Exceptions.propagate(e);
      }
    };
  }

  @Bean
  public Function<LogLine, Integer> countLogMessageLength() {
    return logLine -> {
      int messageLength = StringUtils.isEmpty(logLine.getMessage()) ? 0 : logLine.getMessage().length();
      log.debug("Received a log with message length of {}", messageLength);
      return messageLength;
    };
  }

  // Credits: https://stackoverflow.com/a/4952066/273567
  private static String generateRandomWords(int numberOfWords) {
    StringBuilder sb = new StringBuilder(numberOfWords);
    Random random = new Random();
    for(int i = 0; i < numberOfWords; i++)
    {
      char[] word = new char[random.nextInt(8)+3];
      for(int j = 0; j < word.length; j++) {
        word[j] = (char)('a' + random.nextInt(26));
      }
      sb.append(word).append(' ');
    }
    return sb.toString();
  }
}
