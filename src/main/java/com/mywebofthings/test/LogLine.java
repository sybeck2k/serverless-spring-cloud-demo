package com.mywebofthings.test;

import com.fasterxml.jackson.annotation.JsonFormat;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
public class LogLine {

  private List<String> tags;

  private String message;

  @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss", timezone = "UTC")
  private LocalDateTime eventTime;
}
