import { Composition } from "remotion";
import { LaunchVideo } from "./LaunchVideo";
import "./style.css";

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="MyComposition"
      component={LaunchVideo}
      durationInFrames={900}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
